package acl

// ACLConfig defines the strict port restrictions.
// Only SSH (port 22) traffic is allowed in the virtual network.
const ACLRules = `{
  "acls": [
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