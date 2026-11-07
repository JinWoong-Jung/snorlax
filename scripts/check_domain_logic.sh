#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
check_dir=$(mktemp -d "${TMPDIR:-/tmp}/jammanbo-domain.XXXXXX")
trap 'rm -rf "$check_dir"' EXIT
xcrun swiftc -parse-as-library -module-cache-path "$check_dir/modules" \
  Jammanbo/Health/SleepNight.swift Jammanbo/Health/SleepNormalizer.swift \
  Jammanbo/CheckIn/CheckIn.swift Jammanbo/CheckIn/CheckInRepository.swift Shared/CheckInDelivery.swift \
  Jammanbo/Analysis/AnalysisService.swift Jammanbo/Reporting/ReportSummary.swift \
  Jammanbo/Planning/PlanStore.swift Jammanbo/Reporting/ReportExportStore.swift tests/DomainChecks.swift \
  -o "$check_dir/domain-checks"
"$check_dir/domain-checks"
