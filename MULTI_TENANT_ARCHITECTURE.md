# Multi-Tenant Smart Server Architecture

## 🏗 System Design

### Current State → Multi-Tenant State

**Current**: Single server, single experiment
**Target**: Multiple customers, multiple servers, multiple experiments per customer

---

## 🔧 Technical Implementation

### 1. Customer Configuration System

#### Customer Config Schema
```json
{
  "customer_id": "cust_abc123",
  "email": "founder@startup.com",
  "subscription": {
    "plan": "pro",
    "domains_limit": 5,
    "experiments_limit": 20
  },
  "domains": [
    {
      "id": "dom_xyz789",
      "name": "mystartup.com",
      "server_id": "hetzner_456",
      "status": "active",
      "experiments": [
        {
          "id": "exp_001",
          "type": "landing_page",
          "template": "saas_landing",
          "config": {
            "fathom_site_id": "UQBOCDXH",
            "stripe_link": "https://buy.stripe.com/...",
            "components": ["hero", "problem", "solution", "proof", "cta"]
          }
        }
      ]
    }
  ]
}
```

#### Smart Server Customer Config
```bash
# /opt/smart/customer.conf
CUSTOMER_ID="cust_abc123"
DOMAIN_ID="dom_xyz789"
EXPERIMENTS='["exp_001","exp_002"]'
API_KEY="sk_live_..."
DASHBOARD_URL="https://app.smartserver.ai/dashboard"
```

### 2. Multi-Tenant Experiment Loading

#### Enhanced Agent Script
```bash
#!/usr/bin/env bash
# /opt/smart/bin/agent.sh (multi-tenant version)

# Load customer config
. /opt/smart/customer.conf

# Load experiments for this customer
EXPERIMENTS_DIR="/opt/smart/experiments"
CUSTOMER_EXPERIMENTS=$(echo "$EXPERIMENTS" | jq -r '.[]')

for exp_id in $CUSTOMER_EXPERIMENTS; do
  if [ -d "$EXPERIMENTS_DIR/$exp_id" ]; then
    echo "Running experiment: $exp_id"
    
    # Load experiment-specific config
    . "$EXPERIMENTS_DIR/$exp_id/config.sh"
    
    # Run experiment
    bash "$EXPERIMENTS_DIR/$exp_id/run.sh"
    
    # Report results to central API
    bash /opt/smart/bin/report_results.sh "$exp_id"
  fi
done
```

### 3. Central API for Results Aggregation

#### Results Reporting Script
```bash
#!/usr/bin/env bash
# /opt/smart/bin/report_results.sh

EXP_ID="$1"
RESULTS_FILE="/opt/smart/var/runs/latest.json"

# Send results to central API
curl -X POST "https://api.smartserver.ai/v1/results" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"customer_id\": \"$CUSTOMER_ID\",
    \"domain_id\": \"$DOMAIN_ID\",
    \"experiment_id\": \"$EXP_ID\",
    \"results\": $(cat "$RESULTS_FILE")
  }"
```

#### Central API Endpoints
```typescript
// Express.js API at api.smartserver.ai

// POST /v1/results - Receive experiment results
app.post('/v1/results', async (req, res) => {
  const { customer_id, domain_id, experiment_id, results } = req.body;
  
  // Store results in database
  await db.results.create({
    customer_id,
    domain_id,
    experiment_id,
    results,
    timestamp: new Date()
  });
  
  // Update customer dashboard
  await updateCustomerDashboard(customer_id);
  
  res.json({ status: 'success' });
});

// GET /v1/experiments/:customer_id - Get customer experiments
app.get('/v1/experiments/:customer_id', async (req, res) => {
  const experiments = await db.experiments.findMany({
    where: { customer_id: req.params.customer_id }
  });
  
  res.json(experiments);
});

// POST /v1/deploy - Deploy new server
app.post('/v1/deploy', async (req, res) => {
  const { customer_id, domain, experiments } = req.body;
  
  // Create Hetzner server
  const server = await hetzner.createServer({
    name: `smart-${domain}`,
    user_data: generateCloudInit(customer_id, domain, experiments)
  });
  
  // Setup DNS
  await cloudflare.createRecord(domain, server.ip);
  
  res.json({ server_id: server.id, status: 'deploying' });
});
```

### 4. Dynamic Cloud-Init Generation

#### Cloud-Init Template
```yaml
#cloud-config
# Generated for customer: ${customer_id}
# Domain: ${domain}
# Experiments: ${experiments}

runcmd:
  # Install dependencies
  - apt-get update
  - apt-get install -y jq curl nginx certbot python3-certbot-nginx
  
  # Clone smart server
  - git clone https://github.com/smartserver-ai/smart-server.git /opt/smart
  
  # Install smart server
  - cd /opt/smart && bash deploy/install.sh
  
  # Configure for customer
  - echo "CUSTOMER_ID=${customer_id}" >> /opt/smart/customer.conf
  - echo "DOMAIN_ID=${domain_id}" >> /opt/smart/customer.conf
  - echo "EXPERIMENTS='${experiments}'" >> /opt/smart/customer.conf
  - echo "API_KEY=${api_key}" >> /opt/smart/customer.conf
  
  # Download customer-specific experiments
  - bash /opt/smart/bin/download_experiments.sh ${customer_id}
  
  # Setup domain
  - bash /opt/smart/bin/setup_domain.sh ${domain}
  
  # Start smart server
  - systemctl enable smart-server
  - systemctl start smart-server
```

### 5. Experiment Template System

#### Template Structure
```
/opt/smart/templates/
├── landing_pages/
│   ├── saas_landing/
│   │   ├── meta.json
│   │   ├── components/
│   │   └── config.sh
│   ├── ecommerce_landing/
│   └── agency_landing/
├── performance/
│   ├── nginx_optimization/
│   └── cache_optimization/
└── conversion/
    ├── checkout_flow/
    └── signup_flow/
```

#### Template Download Script
```bash
#!/usr/bin/env bash
# /opt/smart/bin/download_experiments.sh

CUSTOMER_ID="$1"
TEMPLATES_API="https://api.smartserver.ai/v1/templates"

# Get customer's experiment templates
TEMPLATES=$(curl -s -H "Authorization: Bearer $API_KEY" \
  "$TEMPLATES_API/$CUSTOMER_ID")

# Download each template
echo "$TEMPLATES" | jq -r '.[] | .id' | while read template_id; do
  echo "Downloading template: $template_id"
  
  # Download template files
  curl -s -H "Authorization: Bearer $API_KEY" \
    "$TEMPLATES_API/$template_id/download" | tar -xz -C /opt/smart/experiments/
done
```

---

## 🎯 Customer Dashboard

### Real-Time Status Dashboard
```typescript
// Next.js dashboard at app.smartserver.ai

interface CustomerDashboard {
  customer: Customer;
  domains: Domain[];
  experiments: Experiment[];
  results: ExperimentResult[];
}

// Real-time updates via WebSocket
const Dashboard = () => {
  const [dashboard, setDashboard] = useState<CustomerDashboard>();
  
  useEffect(() => {
    const ws = new WebSocket('wss://api.smartserver.ai/ws');
    
    ws.onmessage = (event) => {
      const update = JSON.parse(event.data);
      setDashboard(prev => mergeDashboard(prev, update));
    };
    
    return () => ws.close();
  }, []);
  
  return (
    <div>
      <h1>Smart Server Dashboard</h1>
      
      {dashboard?.domains.map(domain => (
        <DomainCard key={domain.id} domain={domain} />
      ))}
      
      <ExperimentsList experiments={dashboard?.experiments} />
      <ResultsChart results={dashboard?.results} />
    </div>
  );
};
```

### Domain Management
```typescript
const DomainCard = ({ domain }: { domain: Domain }) => {
  return (
    <div className="domain-card">
      <h3>{domain.name}</h3>
      <StatusBadge status={domain.status} />
      
      <div className="metrics">
        <Metric label="Uptime" value="99.9%" />
        <Metric label="Experiments" value={domain.experiments.length} />
        <Metric label="Improvement" value="+23%" />
      </div>
      
      <div className="actions">
        <Button onClick={() => pauseDomain(domain.id)}>Pause</Button>
        <Button onClick={() => addExperiment(domain.id)}>Add Experiment</Button>
      </div>
    </div>
  );
};
```

---

## 🔄 Deployment Automation

### Customer Onboarding Flow
```typescript
// 1. Customer signs up
const signup = async (email: string) => {
  const customer = await db.customers.create({
    email,
    subscription: { plan: 'starter', domains_limit: 1 }
  });
  
  return customer;
};

// 2. Customer adds domain
const addDomain = async (customerId: string, domain: string) => {
  // Validate domain ownership
  const isValid = await validateDomainOwnership(domain);
  if (!isValid) throw new Error('Domain validation failed');
  
  // Create server
  const server = await hetzner.createServer({
    name: `smart-${domain}`,
    user_data: generateCloudInit(customerId, domain, [])
  });
  
  // Setup DNS
  await cloudflare.createRecord(domain, server.ip);
  
  // Store domain
  const domainRecord = await db.domains.create({
    customer_id: customerId,
    name: domain,
    server_id: server.id,
    status: 'deploying'
  });
  
  return domainRecord;
};

// 3. Customer adds experiments
const addExperiment = async (domainId: string, templateId: string) => {
  const experiment = await db.experiments.create({
    domain_id: domainId,
    template_id: templateId,
    status: 'pending'
  });
  
  // Deploy experiment to server
  await deployExperiment(domainId, experiment);
  
  return experiment;
};
```

### Server Provisioning
```typescript
const deployExperiment = async (domainId: string, experiment: Experiment) => {
  const domain = await db.domains.findUnique({ where: { id: domainId } });
  const server = await hetzner.getServer(domain.server_id);
  
  // SSH into server and deploy experiment
  const ssh = new SSH({
    host: server.public_net.ipv4.ip,
    username: 'root',
    privateKey: process.env.HETZNER_SSH_KEY
  });
  
  await ssh.exec(`bash /opt/smart/bin/deploy_experiment.sh ${experiment.id}`);
};
```

---

## 📊 Analytics & Monitoring

### Cross-Customer Analytics
```typescript
// Aggregate insights across all customers
const getPlatformInsights = async () => {
  const insights = await db.$queryRaw`
    SELECT 
      experiment_type,
      AVG(improvement_percentage) as avg_improvement,
      COUNT(*) as total_experiments,
      COUNT(CASE WHEN improvement_percentage > 10 THEN 1 END) as successful_experiments
    FROM experiment_results 
    WHERE created_at > NOW() - INTERVAL '30 days'
    GROUP BY experiment_type
  `;
  
  return insights;
};
```

### Customer Success Metrics
```typescript
const getCustomerHealth = async (customerId: string) => {
  const health = await db.$queryRaw`
    SELECT 
      COUNT(DISTINCT domain_id) as active_domains,
      COUNT(*) as total_experiments,
      AVG(improvement_percentage) as avg_improvement,
      MAX(created_at) as last_experiment
    FROM experiment_results 
    WHERE customer_id = ${customerId}
  `;
  
  return health;
};
```

---

## 🔐 Security & Isolation

### Customer Data Isolation
```typescript
// Each customer's data is isolated
const getCustomerData = async (customerId: string, userId: string) => {
  // Verify user owns customer
  const customer = await db.customers.findFirst({
    where: { id: customerId, user_id: userId }
  });
  
  if (!customer) throw new Error('Unauthorized');
  
  // Return only customer's data
  return db.experiments.findMany({
    where: { customer_id: customerId }
  });
};
```

### Server Security
```bash
# Each server is isolated with unique API keys
# /opt/smart/bin/security.sh

# Generate unique API key for this server
API_KEY=$(openssl rand -hex 32)
echo "API_KEY=\"$API_KEY\"" >> /opt/smart/customer.conf

# Setup firewall rules
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# Setup fail2ban
apt-get install -y fail2ban
systemctl enable fail2ban
systemctl start fail2ban
```

---

## 🚀 Implementation Timeline

### Week 1-2: Core Multi-Tenant Infrastructure
- [ ] Customer configuration system
- [ ] Central API for results aggregation
- [ ] Dynamic cloud-init generation
- [ ] Basic customer dashboard

### Week 3-4: Experiment Template System
- [ ] Template download system
- [ ] Customer-specific experiment loading
- [ ] Template marketplace
- [ ] Experiment deployment automation

### Week 5-6: Customer Portal
- [ ] Domain management
- [ ] Experiment configuration
- [ ] Real-time status updates
- [ ] Billing integration

### Week 7-8: Analytics & Monitoring
- [ ] Cross-customer analytics
- [ ] Customer success metrics
- [ ] Performance monitoring
- [ ] Alert system

---

## 💰 Cost Structure

### Infrastructure Costs (per customer):
- **Hetzner Server**: $3.50/month
- **Cloudflare DNS**: $0/month (free tier)
- **API Hosting**: $0.50/month
- **Total**: $4/month per customer

### Revenue per Customer:
- **Starter Plan**: $29/month
- **Gross Margin**: 86% ($25 profit per customer)

### Break-even:
- **Fixed Costs**: $2,000/month (development, hosting, support)
- **Break-even**: 80 customers
- **Target**: 500 customers by month 12

---

**This multi-tenant architecture transforms the Smart Server from a single-use tool into a scalable SaaS platform that can serve thousands of customers simultaneously.**
