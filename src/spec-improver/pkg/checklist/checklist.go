package checklist

import (
	"io/ioutil"
	"gopkg.in/yaml.v2"
)

type QualityChecklist struct {
	ContentQuality         []string `yaml:"content_quality"`
	RequirementCompleteness []string `yaml:"requirement_completeness"`
	FeatureReadiness       []string `yaml:"feature_readiness"`
}

func ParseChecklist(path string) (*QualityChecklist, error) {
	data, err := ioutil.ReadFile(path)
	if err != nil {
		return nil, err
	}

	var checklist QualityChecklist
	err = yaml.Unmarshal(data, &checklist)
	if err != nil {
		return nil, err
	}

	return &checklist, nil
}
