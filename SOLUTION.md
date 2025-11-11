# Solution Steps

1. Create the shell script file (e.g., timesheet_summarizer.sh) and set bash as the interpreter with '#!/bin/bash'.

2. Accept the input CSV file path as a required command-line argument; if missing, print usage and exit.

3. Check if the input file exists and is readable. If not, print an error message and exit.

4. Create temporary files to hold intermediate calculation results: total hours per employee, hours per employee per week, project hours, malformed lines, and unique employee IDs.

5. Iterate through the CSV file (skipping header) line by line, using 'while read -r ...', splitting each line on commas into four variables: EmployeeID, Date, HoursWorked, ProjectName.

6. Trim spaces from each field using 'xargs'. Validate each field: presence, correct HoursWorked numeric format, and Date format (YYYY-MM-DD). Handle invalid lines by writing them to the malformed lines file and continue.

7. For valid lines:

8. - Append EmployeeID to the employee names file for later uniqueness extraction.

9. - Write EmployeeID and HoursWorked pairs to the per-employee hours temp file.

10. - Write EmployeeID, Week (iso week from date), HoursWorked to the per-employee-week temp file.

11. - Write ProjectName and HoursWorked to the project temp file.

12. Use 'sort | uniq' on collected employee IDs to get a unique list of employees.

13. Aggregate total hours worked per employee using 'awk' over the temp file of employee hours.

14. For weekly calculations, use 'awk' to sum hours per (EmployeeID, Week) and identify employees who worked more than 40 hours in any week.

15. Sum hours per project using 'awk', then use 'sort' to find the most worked-on project and its total hours.

16. Print a clear summary table: for each employee, output their total hours and whether they exceeded 40 hours in any week.

17. Print the most worked-on project with its total hours.

18. Print any malformed lines encountered, or report if there were none.

19. Clean up all temporary files.

