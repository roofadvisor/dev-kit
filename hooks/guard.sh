#!/usr/bin/env bash
# dev-kit PreToolUse guard. Exit 2 = hard block, stderr returned to Claude.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/_parse.sh"
hook_opted_in || exit 0

input=$(cat)
cmd=$(hook_field "$input" "command")
# Which field it came from matters for the dotenv rule below: a command can be
# read for intent (`cat` leaks, `test -f` does not), a bare path cannot. Read
# would dump the file and an Edit payload carries its content, so a path gets
# the strict treatment.
via_path=""
[ -z "$cmd" ] && { cmd=$(hook_field "$input" "file_path"); [ -n "$cmd" ] && via_path=1; }
[ -z "$cmd" ] && { cmd=$(hook_field "$input" "path"); [ -n "$cmd" ] && via_path=1; }

# A guard that cannot read its input must not pretend to pass. This hook is
# wired with a matcher (Write|Edit|Bash), so every payload it sees MUST yield a
# command or path — key-present-but-nothing-extracted is a parse failure, not
# a pass ({"tool_input":{}} and truncated payloads land here).
if [ -z "$cmd" ] && [ -n "$input" ]; then
  log_deny "G-03" "no extractable field from tool input"
  echo "BLOCKED: guard.sh could not extract a command or path from the tool input." >&2
  echo "Install jq or python3, or fix the hook/matcher. Refusing to allow unverified." >&2
  exit 2
fi
[ -z "$cmd" ] && exit 0

# deny <rule-id> <message>. If a deny ever needs the id UNREGISTERED, that is
# a registry-honesty gap: give the rule a row (IDs are permanent, A9) before
# shipping the deny — the fire report flags UNREGISTERED loudly for a reason.
deny() { log_deny "$1" "$cmd"; echo "BLOCKED by dev-kit [$1]: $2" >&2; exit 2; }

shopt -s nocasematch

# nocasematch (below) turns every bare-substring pattern into an English-word
# pattern too. The rules that follow are therefore matched against the command
# with the documented-safe .env variants removed: the C-01 message tells you to
# use .env.example, so firing C-01 on .env.example contradicts the guard's own
# instruction. Removal, not a separate allow-arm — `case` stops at the first
# match, so an allow-arm for .env.example would skip every rule after it and
# `cat .env.example && git push --force` would sail through.
scrubbed=${cmd//.env.example/}
scrubbed=${scrubbed//.env.sample/}
scrubbed=${scrubbed//.env.template/}

# C-03 is checked here rather than in the case below because it needs two
# conditions, not one substring. A bare `TRUNCATE` match denies the English word
# "truncated" — that is not hypothetical, it denied this repo's own commit
# message and then denied the `grep truncate hooks/guard.sh` that went looking
# for the cause. So: either an unambiguous two-word SQL form, or a bare verb in
# a command that is demonstrably talking to a database.
sql_hit=""
case "$scrubbed" in
  *"DROP DATABASE"*|*"DROP SCHEMA"*|*"TRUNCATE TABLE"*|*"TRUNCATE ONLY"*) sql_hit=1 ;;
esac
if [ -z "$sql_hit" ]; then
  case "$scrubbed" in
    *psql*|*mysql*|*mariadb*|*sqlite3*|*psycopg*|*dbshell*|*".sql"*)
      case "$scrubbed" in
        *TRUNCATE*|*"DROP TABLE"*|*"DROP DATABASE"*|*"DROP SCHEMA"*) sql_hit=1 ;;
      esac ;;
  esac
fi
[ -n "$sql_hit" ] && deny "C-03" "destructive database operation. Use a migration, or scripts/dev-reset.sh locally."

# Dotenv files: the question is whether a VALUE reaches this transcript, not
# whether a filename appears in the command.
#
# Matching the filename alone denied `test -f`, `ls`, `wc`, `cp`, `cut -d= -f1`
# and every `process.env` / `os.environ` in ordinary Node and Python — none of
# which emit a value — while catching `cat`, which does. A guard that blocks the
# safe majority is one people learn to route around, and the industry consensus
# on secret scanning says the fix is narrower rules, not broader ones.
#
# Two stages: is a dotenv file referenced at all, and if so would this command
# print it? The reference test is anchored so a property access (preceded by an
# identifier character) is not a filename.
#
# Known imprecision: `case` globbing cannot prove the reader verb TARGETS the
# dotenv file, only that both appear. `cat README.md && test -f .env` therefore
# denies. That fails safe, it is rare, and the alternative is a shell parser in
# a hook that has to stay fast and dependency-free.
envref=""
case "$scrubbed" in
  ".env"*|*[!A-Za-z0-9_]".env"*) envref=1 ;;
esac
if [ -n "$envref" ]; then
  # ALLOWLIST, not a denylist. A previous revision listed the verbs that print a
  # file — cat, head, less and eight others — and allowed everything else. An
  # adversarial review measured that against the filename rule it replaced: 65
  # commands the old rule denied were newly allowed, only 4 of them intended.
  # The other 61 were working leaks — awk, sed -n, python3 -c, base64,
  # `source .env && env`, `docker run --env-file`, `curl -d @.env`, `scp`, and
  # `tac`, which is cat spelled backwards. That last one is the argument: if a
  # verb list loses to reversing a word, the list was never the mechanism.
  # "Which programs print a file" has no finite answer; "which operations on a
  # secrets file are safe" has a short one, so enumerate that instead and deny
  # by default.
  #
  # Safe means the command emits no value and moves none anywhere readable.
  # Every segment of the command must be safe — one unsafe segment condemns the
  # whole line, because `test -f .env && cat .env` is not a safe command.
  safe=1

  # Constructs that can smuggle a read past any verb check at all. Command
  # substitution, eval, xargs and a redirect FROM the file all execute or emit
  # something this parser cannot see.
  case "$scrubbed" in
    *'$('*|*'`'*|*eval*|*xargs*|*'<'*) safe="" ;;
  esac

  if [ -n "$safe" ]; then
    # Split on the separators that start a new command, then require every
    # segment's leading verb to be one we have reasoned about.
    seps=${scrubbed//&&/$'\n'}; seps=${seps//||/$'\n'}
    seps=${seps//;/$'\n'};      seps=${seps//|/$'\n'}
    while IFS= read -r seg; do
      seg=${seg#"${seg%%[![:space:]]*}"}          # ltrim
      [ -z "$seg" ] && continue
      # Strip leading control-flow keywords rather than allowing them. Splitting
      # on `;` yields `do cat .env`, whose first word is `do` — so treating `do`
      # as safe would wave the `cat` straight through. Measured: it did, until
      # this loop was added. Keywords are transparent, not permitted.
      while :; do
        w=${seg%%[[:space:]]*}
        case "$w" in
          # A loop or case HEADER runs no command — `for p in a b` is a variable
          # and a word list, so stripping the keyword would leave `p` as the
          # "verb". The whole segment is transparent.
          for|case) seg=""; break ;;
          # These PRECEDE a command on the same segment: strip and judge what
          # follows. `do cat .env` must be judged on the cat.
          do|done|then|else|elif|fi|esac|if|while|until|'{'|'}')
              rest=${seg#"$w"}; rest=${rest#"${rest%%[![:space:]]*}"}
              [ -z "$rest" ] && { seg=""; break; }
              seg=$rest ;;
          *)  break ;;
        esac
      done
      [ -z "$seg" ] && continue                   # segment was only keywords
      verb=${seg%%[[:space:]]*}; verb=${verb##*/}  # first word, path stripped
      case "$verb" in
        # Existence, metadata, shape. Emit nothing from inside the file.
        test|'['|'[['|ls|wc|stat|file|du|touch|true|:|cd|echo|printf|mkdir|chmod) ;;
        # Copy and move: bytes go somewhere, nothing is printed. Restricted to a
        # dotenv-shaped destination, so `cp .env docs/notes.txt` — which stages a
        # secret for a later read or a commit — is not quietly safe.
        cp|mv) dest=${seg##* }                       # last word is the destination
               case "$dest" in *.env|*.env.*|*.envrc) ;; *) safe="" ;; esac ;;
        # In-place only. Without -i, sed prints.
        sed) case "$seg" in *" -i"*) ;; *) safe="" ;; esac ;;
        # Counts, verdicts and filenames only. -C is CONTEXT and prints matches;
        # nocasematch would have folded it into -c, so match case-sensitively.
        grep|egrep|rg)
            case "$seg" in
              *" -c "*|*" -q "*|*" -l "*|*" -L "*|*--count*|*--quiet*|*--files-with-matches*) ;;
              *) safe="" ;;
            esac ;;
        # Key names only. -f2 is every value, -c is a character range over the
        # whole line: the previous deny message recommended `cut -d= -f1` while
        # allowing both of those.
        cut) case "$seg" in *"-f1"*|*"-f 1"*) ;; *) safe="" ;; esac ;;
        *) safe="" ;;
      esac
      [ -z "$safe" ] && break
    done <<< "$seps"
  fi

  # A file-targeting tool gives no verb to judge at all. Read dumps the file
  # outright and an Edit payload carries its content, so a bare path is never
  # safe. This branch survived the review's bypass attempts intact.
  [ -n "$via_path" ] && safe=""

  [ -z "$safe" ] && deny "C-01" "that would expose the file's values — printing them here, or copying them somewhere they can be read or committed. Safe: test -f, ls, wc, stat, cut -d= -f1 for key names, grep -c/-q/-l, sed -i, and cp/mv to a .env* name. Reference a value as \$VAR."
fi

# Credential literals by issuer shape. The named-assignment arm below only
# catches a value assigned to a recognisably-named variable, so a bare
# `printf sk-live-… > file` walks past it — a literal secret in the command
# text, which this transcript then keeps.
#
# A regex, not a glob, because the discriminator is "followed by a long token":
# `sk-SK` is a locale and `$npm_package_version` is in every package.json
# script, while `sk-<40 chars>` and `AKIA<16>` are keys. An earlier glob version
# denied both of those false positives, the npm one in every repo the plugin is
# installed in.
#
# nocasematch is off for this test on purpose: the AWS prefixes are uppercase by
# definition, and folding case would deny the word "asia".
#
# Known limit, stated rather than implied: this catches KNOWN ISSUERS ONLY. A
# bare hex token, a JWT, or a `postgres://user:pass@host` URL has no prefix to
# match and passes. Entropy scoring would reach those; it is deliberately not
# here, because a hook must stay fast and dependency-free, and a scorer tuned
# loose enough to catch them flags every UUID and content hash.
shopt -u nocasematch
if [[ "$scrubbed" =~ (^|[^A-Za-z0-9_])(sk-[A-Za-z0-9]{12,}|sk-proj-|sk-live-|sk-test-|sk_live_|sk_test_|rk_live_|pk_live_|ghp_[A-Za-z0-9]{8,}|gho_[A-Za-z0-9]{8,}|ghs_[A-Za-z0-9]{8,}|ghu_[A-Za-z0-9]{8,}|github_pat_|glpat-[A-Za-z0-9_-]{12,}|xox[baprs]-[A-Za-z0-9-]{10,}|AKIA[A-Z0-9]{12,}|ASIA[A-Z0-9]{12,}|shpat_[a-f0-9]{16,}|hf_[A-Za-z0-9]{20,}|-----BEGIN[ A-Z]*PRIVATE\ KEY) ]]; then
  shopt -s nocasematch
  deny "C-01" "that is a credential literal sitting in the command text, where this transcript keeps it. Put the value in your shell or a dotenv file and reference it as \$VAR."
fi
shopt -s nocasematch

# `.key` and `keystore` are file markers and ordinary code at the same time —
# a property access, a jq filter, an English word. Anchoring `.key` on what
# FOLLOWS it fixed the identifier that KEEPS GOING (`list(d.keys())`,
# `$cfg.keyboard`), but a property access ENDS exactly where an extension ends,
# so `d.key },` and `jq '.rows[].key'` denied too, and `grep keystore` denied
# the search for the cause — the story C-03 tells about a bare TRUNCATE.
#
# The `.env` anchor above cannot be borrowed: a dotenv file has nothing before
# its dot, so an identifier there proves a property. A key file always has
# something before its dot, which makes `server.key` and `d.key` the same
# shape. The token alone can never decide.
#
# So two signals, the way C-03 takes two: the marker is referenced, AND either
# it sits in a path or the command carries a verb that would put the file's
# bytes into this transcript or into another file. `ls`, `test -f` and `stat`
# are not such verbs — the dotenv arm above already calls them safe, for the
# case that guards actual values.
#
# Known gap, stated rather than hidden: an interpreter that opens the file
# itself — `python3 -c "open('site.key').read()"` — carries neither signal.
# The names that only ever mean key material (`id_rsa`, `.pem`,
# `credentials.json`) still deny on any mention below, and a bare file_path is
# always strict, which is the route a Read or an Edit would take.
keyref=""
case "$scrubbed" in
  # A path or an extension, never the bare word.
  *"keystore/"*|*"/keystore"*|*".keystore"*) keyref=1 ;;
  *".key"|*".key"[!A-Za-z0-9_]*) keyref=2 ;;
esac
if [ "$keyref" = 2 ]; then
  keyref=""
  # A path: the slash and the extension in one token, no whitespace between.
  # `scripts/x.py -c 'print(d.key)'` has a slash and a `.key`, but not in the
  # same word, and that is the whole difference.
  [[ "$scrubbed" =~ /[^[:space:]]*\.key([^A-Za-z0-9_]|$) ]] && keyref=1
  # Or a verb that reads the file out, or puts its bytes somewhere they persist.
  # Judged in VERB POSITION and case-sensitively, both learned the hard way on
  # this fix's own commit: `git push origin HEAD` matched `head` when the list
  # was applied to the whole line under nocasematch. The verb of that command
  # is `git`.
  if [ -z "$keyref" ]; then
    seps=${scrubbed//&&/$'\n'}; seps=${seps//||/$'\n'}
    seps=${seps//;/$'\n'};      seps=${seps//|/$'\n'}
    shopt -u nocasematch
    while IFS= read -r seg; do
      seg=${seg#"${seg%%[![:space:]]*}"}
      # Control-flow keywords are transparent, not permitted — the dotenv arm
      # above has the measurement that made that necessary.
      while :; do
        w=${seg%%[[:space:]]*}
        case "$w" in
          for|case) seg=""; break ;;
          do|done|then|else|elif|fi|esac|if|while|until|'{'|'}')
              rest=${seg#"$w"}; rest=${rest#"${rest%%[![:space:]]*}"}
              [ -z "$rest" ] && { seg=""; break; }
              seg=$rest ;;
          *)  break ;;
        esac
      done
      [ -z "$seg" ] && continue
      verb=${seg%%[[:space:]]*}; verb=${verb##*/}
      case "$verb" in
        cat|tac|bat|less|more|head|tail|nl|strings|xxd|od|base64|cp|mv|scp|rsync|install|tar|zip|curl|openssl|ssh-keygen|ssh-add|gpg|keytool|certutil)
            keyref=1; break ;;
      esac
    done <<< "$seps"
    shopt -s nocasematch
  fi
  # Read dumps the file and an Edit payload carries its content, so a bare path
  # is never safe — the same branch the dotenv arm relies on.
  [ -n "$via_path" ] && keyref=1
fi
[ -n "$keyref" ] && deny "C-01" "key material is off-limits. Reference it by path in config; never read it into a transcript."

case "$scrubbed" in
  # Key material, unlike a dotenv file, has no safe read: any mention denies.
  # It is also rare in ordinary work, so the strictness costs nothing.
  *"id_rsa"*|*".pem"*|*"credentials.json"*)
      deny "C-01" "key material is off-limits. Reference it by path in config; never read it into a transcript." ;;
  # Unambiguous crypto terms: no ordinary-code reading, so no second signal.
  *"mnemonic"*|*"seed phrase"*)
      deny "C-01" "key material is off-limits." ;;
  *"PRIVATE_KEY"*|*"SECRET_KEY"*|*"_TOKEN="*|*"API_KEY="*)
      deny "C-01" "never interpolate a credential into a command. Reference the env var by name." ;;
  # (Credential literals by issuer shape are matched below, with a regex —
  #  glob patterns cannot express "followed by a long token", which is what
  #  separates a real key from a word that merely starts the same way.)
  # The flag itself, terminal or followed by whitespace — not every flag that
  # merely starts with it (`--broadcast-mode=off` broadcasts nothing).
  *"--broadcast"|*"--broadcast"[[:space:]]*)
      deny "KS-01" "no transaction broadcasting from an agent session. Use anvil or a fork." ;;
  # An endpoint or a network selection, not the word. `cat docs/mainnet.md` and
  # a commit message about the mainnet launch are not RPC calls.
  *"infura.io"*|*"alchemy.com"*|*"polygon-rpc.com"*|*"://"*"mainnet"*)
      deny "KS-02" "no mainnet RPC in an agent session. Use a local or forked chain." ;;
  *"--network mainnet"*|*"--network=mainnet"*|*"--chain mainnet"*|*"--chain=mainnet"*)
      deny "KS-02" "no mainnet RPC in an agent session. Use a local or forked chain." ;;
  *"--rpc-url"*"mainnet"*|*"--fork-url"*"mainnet"*)
      deny "KS-02" "no mainnet RPC in an agent session. Use a local or forked chain." ;;
  # Root and home themselves — terminal, or with a following argument or glob.
  # `rm -rf /` as a bare substring also denies `rm -rf /tmp/scratch`, which is
  # exactly where a session is told to put its scratch work.
  *"rm -rf /"|*"rm -rf ~"|*"rm -rf ~/"|*"rm -rf /"[[:space:]]*|*"rm -rf ~"[[:space:]]*|*"rm -rf /*"*|*"rm -rf ~/*"*|*":(){"*)
      deny "C-09" "destructive command." ;;
  *"git push --force"*|*"push -f "*|*"push -f")
      deny "C-02" "force-push is human-only." ;;
esac
exit 0
