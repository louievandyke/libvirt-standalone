package cli

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/spf13/cobra"

	"github.com/libvirt-standalone/chaos/internal/report"
)

var (
	reportFormat string
)

var reportCmd = &cobra.Command{
	Use:   "report <file>",
	Short: "Display or convert a chaos test report",
	Long: `Display or convert a chaos test report from JSON format.

The report can be output in various formats:
  table     Human-readable table (default)
  json      JSON format
  markdown  Markdown format
  compact   Single-line summary

Examples:
  chaos report results.json
  chaos report results.json --format markdown
  chaos report results.json --format compact`,
	Args: cobra.ExactArgs(1),
	RunE: runReport,
}

func init() {
	reportCmd.Flags().StringVarP(&reportFormat, "format", "f", "table", "output format (table, json, markdown, compact)")
	rootCmd.AddCommand(reportCmd)
}

func runReport(cmd *cobra.Command, args []string) error {
	filePath := args[0]

	// Read the report file
	data, err := os.ReadFile(filePath)
	if err != nil {
		return fmt.Errorf("reading report file: %w", err)
	}

	// Parse the report
	var rep report.Report
	if err := json.Unmarshal(data, &rep); err != nil {
		return fmt.Errorf("parsing report: %w", err)
	}

	// Format and output
	var output string
	switch reportFormat {
	case "table":
		output = rep.FormatTable()
	case "json":
		output = rep.FormatJSON()
	case "markdown", "md":
		output = rep.FormatMarkdown()
	case "compact":
		output = rep.FormatCompact()
	default:
		return fmt.Errorf("unknown format: %s", reportFormat)
	}

	fmt.Print(output)
	return nil
}
