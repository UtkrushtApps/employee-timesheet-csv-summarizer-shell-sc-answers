#!/bin/bash

# Employee Timesheet CSV Summarizer
# Usage: ./timesheet_summarizer.sh timesheet.csv

# Check for exactly one argument
if [ $# -ne 1 ]; then
  echo "Usage: $0 <timesheet.csv>" >&2
  exit 1
fi

INPUT_FILE="$1"

# Check: file exists
if [ ! -f "$INPUT_FILE" ]; then
  echo "Error: File '$INPUT_FILE' not found." >&2
  exit 2
fi

# Check: file readable
if [ ! -r "$INPUT_FILE" ]; then
  echo "Error: File '$INPUT_FILE' is not readable." >&2
  exit 3
fi

echo "Processing file: $INPUT_FILE"

# Temporary files
TMP_EMP_HOURS=$(mktemp)
TMP_EMP_WEEK=$(mktemp)
TMP_PROJECTS=$(mktemp)
TMP_MALFORMED=$(mktemp)
TMP_EMP_NAMES=$(mktemp)

declare -A EMP_HOURS
declare -A EMP_WEEK_HOURS
declare -A PROJECT_HOURS

tail -n +2 "$INPUT_FILE" | while IFS=',' read -r empid date hours project
 do
    # Remove leading/trailing spaces
    empid=$(echo "$empid" | xargs)
    date=$(echo "$date" | xargs)
    hours=$(echo "$hours" | xargs)
    project=$(echo "$project" | xargs)

    # Check field count
    if [[ -z "$empid" || -z "$date" || -z "$hours" || -z "$project" ]]; then
        echo "$empid,$date,$hours,$project" >> "$TMP_MALFORMED"
        continue
    fi
    
    # Validate hours is a number (int or float)
    if ! [[ "$hours" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
        echo "$empid,$date,$hours,$project" >> "$TMP_MALFORMED"
        continue
    fi

    # Validate date (YYYY-MM-DD)
    if ! [[ "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        echo "$empid,$date,$hours,$project" >> "$TMP_MALFORMED"
        continue
    fi

    # Compute week id: YEAR-WK (ISO-8601)
    week="$(date -d "$date" +%G-%V 2>/dev/null)"
    if [ -z "$week" ]; then
        echo "$empid,$date,$hours,$project" >> "$TMP_MALFORMED"
        continue
    fi

    # Track unique employee names
    echo "$empid" >> "$TMP_EMP_NAMES"
    
    # Accumulate hours per employee
    echo "$empid $hours" >> "$TMP_EMP_HOURS"

    # Accumulate hours per employee per week
    echo "$empid $week $hours" >> "$TMP_EMP_WEEK"

    # Accumulate hours per project
    echo "$project $hours" >> "$TMP_PROJECTS"
done

# Unique employees
sort "$TMP_EMP_NAMES" | uniq > "$TMP_EMP_NAMES.unique"

# Calculate total hours per employee
awk '{emp[$1]+=$2} END {for (e in emp) print e,emp[e]}' "$TMP_EMP_HOURS" > "$TMP_EMP_HOURS.sum"

# Calculate employee hours per (week, emp)
awk '{e=$1;w=$2;h=$3; key=e "," w; empw[key]+=h} END {for (k in empw) print k,empw[k]}' "$TMP_EMP_WEEK" > "$TMP_EMP_WEEK.sum"

# Find employees who worked >40 hours any week
awk 'NF==3 && $3 > 40 {print $1}' "$TMP_EMP_WEEK.sum" | sort | uniq > "$TMP_EMP_WEEK.over40"

# Calculate hours per project
awk '{proj[$1]+=$2} END {for (p in proj) print p,proj[p]}' "$TMP_PROJECTS" > "$TMP_PROJECTS.sum"

# Determine most worked-on project
MOST_PROJECT="$(sort -k2,2nr "$TMP_PROJECTS.sum" | head -n1 | awk '{print $1}')"
MOST_PROJECT_HOURS="$(sort -k2,2nr "$TMP_PROJECTS.sum" | head -n1 | awk '{print $2}')"

# Output summary
printf "\nSummary Table (EmployeeID | TotalHours | Over40Hours?\n"
printf "---------------------------------------------\n"
while read eid
do
    total="$(awk -v id="$eid" '$1==id {printf "%.2f", $2}' "$TMP_EMP_HOURS.sum")"
    over40="$(grep -Fx "$eid" "$TMP_EMP_WEEK.over40" > /dev/null && echo "Yes" || echo "No")"
    printf "%-15s %-12s %-10s\n" "$eid" "$total" "$over40"
done < "$TMP_EMP_NAMES.unique"
printf "---------------------------------------------\n"
printf "Most worked-on project: %s (Total hours: %s)\n" "$MOST_PROJECT" "$MOST_PROJECT_HOURS"

# Malformed lines report
if [ -s "$TMP_MALFORMED" ]; then
    echo
    echo "Malformed CSV lines encountered:"
    cat "$TMP_MALFORMED"
else
    echo
    echo "No malformed CSV lines encountered."
fi

# Cleanup temp files
rm -f "$TMP_EMP_HOURS" "$TMP_EMP_WEEK" "$TMP_PROJECTS" "$TMP_MALFORMED" "$TMP_EMP_NAMES" "$TMP_EMP_NAMES.unique" "$TMP_EMP_HOURS.sum" "$TMP_EMP_WEEK.sum" "$TMP_EMP_WEEK.over40" "$TMP_PROJECTS.sum"

exit 0
