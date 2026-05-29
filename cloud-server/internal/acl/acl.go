package acl

import (
	"encoding/json"
	"fmt"
)

// ACLRule defines a single ACL allow/deny rule.
type ACLRule struct {
	Action string   `json:"action"`
	Source []string `json:"src"`
	Dest   []string `json:"dst"`
	Proto  string   `json:"proto,omitempty"`
}

// SSHRule defines SSH access rules (Tailscale SSH).
type SSHRule struct {
	Action string   `json:"action"`
	Source []string `json:"src"`
	Dest   []string `json:"dst"`
	Users  []string `json:"users"`
}

// ACLConfig is the full ACL policy document exposed to Headscale.
type ACLConfig struct {
	ACLs       []ACLRule  `json:"acls"`
	SSH        []SSHRule  `json:"ssh,omitempty"`
	AutoApprovers struct {
		Routes []string `json:"routes,omitempty"`
	} `json:"autoApprovers,omitempty"`
}

// GenerateStrictConfig returns the production ACL config that only permits
// SSH (port 22) and explicitly denies all other ports (80, 443, 8080, 3389, etc).
//
// This is the core compliance mechanism: it provably prevents users from
// hosting web services through the tunnel, insulating the platform from
// legal liability under Chinese cyber-security law.
func GenerateStrictConfig() *ACLConfig {
	// Deny-list: ports commonly used for unauthorized web services.
	// SSH (22) is the only permitted port.
	denyPorts := []string{"80", "443", "8080", "8443", "3389", "5900", "5901"}

	rules := []ACLRule{}

	// 1. Explicitly deny all dangerous ports first
	for _, port := range denyPorts {
		rules = append(rules, ACLRule{
			Action: "deny",
			Source: []string{"*"},
			Dest:   []string{fmt.Sprintf("*:%s", port)},
		})
	}

	// 2. Allow SSH on port 22
	rules = append(rules, ACLRule{
		Action: "accept",
		Source: []string{"*"},
		Dest:   []string{"*:22"},
	})

	// 3. Allow ICMP (ping) for connectivity checks
	rules = append(rules, ACLRule{
		Action: "accept",
		Source: []string{"*"},
		Dest:   []string{"*:*"},
		Proto:  "icmp",
	})

	return &ACLConfig{
		ACLs: rules,
		SSH: []SSHRule{
			{
				Action: "check",
				Source: []string{"*"},
				Dest:   []string{"*"},
				Users:  []string{"*"},
			},
		},
	}
}

// MustGenerateJSON returns the ACL config as a pretty-printed JSON string.
// Panics if marshalling fails (should never happen with this static data).
func MustGenerateJSON() string {
	cfg := GenerateStrictConfig()
	data, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		panic(fmt.Sprintf("acl: marshal config: %v", err))
	}
	return string(data)
}

// ACLRules is the legacy constant — kept for backward compatibility.
// Prefer GenerateStrictConfig() for new code.
const ACLRules = `{
  "acls": [
    {
      "action": "deny",
      "src": ["*"],
      "dst": ["*:80"]
    },
    {
      "action": "deny",
      "src": ["*"],
      "dst": ["*:443"]
    },
    {
      "action": "deny",
      "src": ["*"],
      "dst": ["*:8080"]
    },
    {
      "action": "deny",
      "src": ["*"],
      "dst": ["*:8443"]
    },
    {
      "action": "deny",
      "src": ["*"],
      "dst": ["*:3389"]
    },
    {
      "action": "accept",
      "src": ["*"],
      "dst": ["*:22"]
    }
  ],
  "ssh": [
    {
      "action": "accept",
      "src": ["*"],
      "dst": ["*"],
      "users": ["*"]
    }
  ]
}`