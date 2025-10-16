package main

import (
	"fmt"
	"log"
	"os"

	"github.com/urfave/cli/v2"
	"github.com/your-org/spec-improver/internal/analyzer"
	"github.com/your-org/spec-improver/internal/creator"
	"github.com/your-org/spec-improver/pkg/checklist"
)

func main() {
	app := &cli.App{
		Name:  "spec-improver",
		Usage: "A tool to improve component specifications",
		Commands: []*cli.Command{
			{
				Name:      "analyze",
				Usage:     "Analyzes an existing component specification",
				ArgsUsage: "<path-to-spec.md>",
				Action: func(c *cli.Context) error {
					specPath := c.Args().Get(0)
					if specPath == "" {
						return fmt.Errorf("path to specification file is required")
					}

					// For now, we'll use a dummy checklist
					checklist := &checklist.QualityChecklist{}

					improvements, err := analyzer.Analyze(specPath, checklist)
					if err != nil {
						return err
					}

					fmt.Println("Analysis complete. Found the following potential improvements:")
					for _, improvement := range improvements {
						fmt.Println("- ", improvement)
					}

					return nil
				},
			},
			{
				Name:      "create",
				Usage:     "Creates a new component specification",
				ArgsUsage: "<feature-name>",
				Action: func(c *cli.Context) error {
					featureName := c.Args().Get(0)
					if featureName == "" {
						return fmt.Errorf("feature name is required")
					}
					return creator.Create(featureName)
				},
			},
			{
				Name:  "update",
				Usage: "Updates an existing component specification",
				Action: func(c *cli.Context) error {
					fmt.Println("Updating specification...")
					return nil
				},
			},
		},
	}

	err := app.Run(os.Args)
	if err != nil {
		log.Fatal(err)
	}
}
