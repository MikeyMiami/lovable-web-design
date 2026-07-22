#!/usr/bin/env bash
# Telnyx voice miss-detection — synthetic edge-case regression battery.
# Hits the DEPLOYED edge functions with crafted form-encoded payloads (voice soft-verifies,
# so no signature needed) and asserts the branch decision each situation produces.
# Validated live 2026-07-20 (all pass). Re-run after any telnyx-voice-* change.
#
# Usage:  BASE=... ANON=... JWT=... CID=<client_uuid> ./telnyx-voice-edge-tests.sh
#   BASE = https://<project>.supabase.co
#   ANON = anon key ; JWT = a logged-in access token ; CID = pilot client id
#
# After running, inspect: events where type in (telnyx_voice_status_branch, missed_call,
# missed_call_throttled, telnyx_amd_result, telnyx_voice_inbound_branch) for CallSid synth-*.
# Then CLEAN UP: soft-delete +1500555* contacts and exit their missed_call_textback enrollments.
set -euo pipefail
S="$BASE/functions/v1/telnyx-voice-status"
I="$BASE/functions/v1/telnyx-voice-inbound"
FWD="+14197500242"   # a client.call_forwarding_number ; BIZ below must be the client's telnyx_number
BIZ="+14199650288"
post(){ curl -s -X POST "$1" -H "Content-Type: application/x-www-form-urlencoded" "${@:2}"; echo ""; }

# dial-status misses (no AMD) — each should log missed_fired / rule=dial_status
post "$S?client=$CID" --data-urlencode "CallSid=synth-busy-1"   --data-urlencode "From=+15005550101" --data-urlencode "To=$FWD" --data-urlencode "DialCallStatus=busy"
post "$S?client=$CID" --data-urlencode "CallSid=synth-failed-1" --data-urlencode "From=+15005550102" --data-urlencode "To=$FWD" --data-urlencode "DialCallStatus=failed"
post "$S?client=$CID" --data-urlencode "CallSid=synth-cancel-1" --data-urlencode "From=+15005550103" --data-urlencode "To=$FWD" --data-urlencode "DialCallStatus=canceled"

# AMD=unknown then completed  -> no_miss (safe default: don't textback on inconclusive AMD)
post "$S?client=$CID" --data-urlencode "CallSid=synth-unk-1" --data-urlencode "AnsweredBy=unknown"
post "$S?client=$CID" --data-urlencode "CallSid=synth-unk-1" --data-urlencode "From=+15005550104" --data-urlencode "To=$FWD" --data-urlencode "CallStatus=completed"

# AMD=fax then completed  -> missed_fired / amd_machine (fax counts as machine)
post "$S?client=$CID" --data-urlencode "CallSid=synth-fax-1" --data-urlencode "AnsweredBy=fax"
post "$S?client=$CID" --data-urlencode "CallSid=synth-fax-1" --data-urlencode "From=+15005550105" --data-urlencode "To=$FWD" --data-urlencode "CallStatus=completed"

# AMD=human vs DialCallStatus=no-answer (conflict) -> no_miss / amd_human_override (human wins)
post "$S?client=$CID" --data-urlencode "CallSid=synth-hna-1" --data-urlencode "AnsweredBy=human"
post "$S?client=$CID" --data-urlencode "CallSid=synth-hna-1" --data-urlencode "From=+15005550106" --data-urlencode "To=$FWD" --data-urlencode "DialCallStatus=no-answer"

# Double-fire: AMD=machine then TWO terminal legs (parent+forward). Sequential -> leg2 throttled.
post "$S?client=$CID" --data-urlencode "CallSid=synth-dbl-1" --data-urlencode "AnsweredBy=machine_start"
post "$S"             --data-urlencode "CallSid=synth-dbl-1" --data-urlencode "From=+15005550107" --data-urlencode "To=$BIZ" --data-urlencode "CallStatus=completed"
post "$S?client=$CID" --data-urlencode "CallSid=synth-dbl-1" --data-urlencode "From=+15005550107" --data-urlencode "To=$FWD" --data-urlencode "CallStatus=completed"

# Inbound routing: unmapped number -> no_client ; mapped -> dial TeXML with AMD on <Number>
post "$I" --data-urlencode "CallSid=synth-unknownnum" --data-urlencode "From=+15005550108" --data-urlencode "To=+19998887777"
post "$I" --data-urlencode "CallSid=synth-inb-1"      --data-urlencode "From=+15005550109" --data-urlencode "To=$BIZ"
