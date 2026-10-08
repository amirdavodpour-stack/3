  if [ -z "$driver_line_number" ] || [ "$driver_line_number" -le 1 ]; then
    printf 'FAIL: runtime driver invocation is missing from %s.\n' "$runtime" >&2
    exit 1
  fi
  previous_line="$(sed -n "$((driver_line_number - 1))p" "$runtime")"
  if ! printf '%s\n' "$previous_line" | grep -Fq -- 'timeout --foreground --signal=TERM'; then
    printf 'FAIL: runtime driver invocation is not directly continued from timeout; a comment/blank line split the shell command.\n' >&2
    exit 1
  fi
  case "$previous_line" in
    *\\) ;;
    *)
      printf 'FAIL: timeout line no longer uses a shell continuation before flutter drive.\n' >&2
      exit 1
      ;;
  esac
}
driver_invocation_contiguous
require_line "$runtime" 'HOPE_HOST_RUNTIME_DRIVER_WAIT_FOR_NATURAL_EXIT'
require_line "$runtime" 'HOPE_HOST_RUNTIME_DRIVER_FORCE_STOP'