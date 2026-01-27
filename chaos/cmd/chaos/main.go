// Package main provides the entrypoint for the chaos CLI tool.
package main

import (
	"os"

	"github.com/libvirt-standalone/chaos/internal/cli"
)

func main() {
	if err := cli.Execute(); err != nil {
		os.Exit(1)
	}
}
