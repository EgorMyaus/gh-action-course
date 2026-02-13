// =============================================================================
// ReportPortal Configuration for Cucumber-Playwright
// =============================================================================
// Get API token from: ReportPortal UI -> User Profile -> API Keys
// =============================================================================

const rpConfig = {
  token: process.env.RP_TOKEN || 'YOUR_API_TOKEN',
  endpoint: process.env.RP_ENDPOINT || 'http://localhost:8080/api/v1',
  project: process.env.RP_PROJECT || 'default_personal',
  launch: process.env.RP_LAUNCH || 'Cucumber Playwright E2E Tests',
  description: 'Automated E2E tests for React App',
  attributes: [
    { key: 'browser', value: process.env.BROWSER || 'chromium' },
    { key: 'env', value: process.env.NODE_ENV || 'localhost' },
    { key: 'framework', value: 'cucumber-playwright' },
  ],
  rerun: false,
  rerunOf: undefined,
  skippedIssue: true,
  debug: false,
  restClientConfig: {
    timeout: 60000,
  },
};

module.exports = rpConfig;
