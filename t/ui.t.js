#!/usr/bin/env node
import {UserAgent} from '@mojojs/core';
import ServerStarter from '@mojolicious/server-starter';
import {chromium} from 'playwright';
import t from 'tap';

const env = process.env;
const skip = env.TEST_ONLINE === undefined ? 'set TEST_ONLINE to enable this test' : false;

// Wrapper script with fixtures can be found in "t/wrappers/ui.pl"
t.test('Test dashboard ui', {skip, timeout: 60000}, async t => {
  const server = await ServerStarter.newServer();
  await server.launch('perl', ['t/wrappers/ui.pl']);
  const browser = await chromium.launch(env.TEST_HEADLESS === '0' ? {headless: false, slowMo: 500} : {});
  const context = await browser.newContext();
  const page = await context.newPage();
  const url = server.url();

  const errorLogs = [];
  page.on('console', message => {
    if (message.type() === 'error') {
      errorLogs.push(message.text());
    }
  });

  // GitHub actions can be a bit flaky, so better wait for the server
  const ua = new UserAgent();
  await ua.get(url, {timeout: 10000}).catch(error => console.warn(error));

  await t.test('Navigation', async t => {
    await page.goto(url);
    t.equal(await page.innerText('title'), 'Active Incidents');

    await page.click('text=Blocked');
    await page.locator('h1', {hasText: 'Blocked by Tests'}).waitFor();
    t.equal(page.url(), `${url}/blocked`);
    t.equal(await page.innerText('title'), 'Blocked by Tests');

    await page.click('text=Repos');
    await page.locator('h1', {hasText: 'Test Repos'}).waitFor();
    t.equal(page.url(), `${url}/repos`);
    t.equal(await page.innerText('title'), 'Test Repos');

    await page.click('text=Active');
    await page.locator('h1', {hasText: 'Active Incidents'}).waitFor();
    t.equal(await page.innerText('title'), 'Active Incidents');
  });

  await t.test('Overview', async t => {
    await page.goto(url);
    t.match(await page.innerText('tbody tr:nth-of-type(1) td:nth-of-type(1) a'), /16860:perl-Mojolicious/);
    t.match(await page.innerText('tbody tr:nth-of-type(1) td:nth-of-type(2) span'), /testing/);
    t.match(await page.innerText('tbody tr:nth-of-type(2) td:nth-of-type(1) a'), /29722:multipath-tools/);
    t.match(await page.innerText('tbody tr:nth-of-type(2) td:nth-of-type(2) span'), /testing/);
    t.match(await page.innerText('tbody tr:nth-of-type(3) td:nth-of-type(1) a'), /16861:perl-Minion/);
    t.match(await page.innerText('tbody tr:nth-of-type(3) td:nth-of-type(2) span'), /staged/);
    t.match(await page.innerText('tbody tr:nth-of-type(4) td:nth-of-type(1) a'), /30000:gitea-pr/);
    t.match(await page.innerText('tbody tr:nth-of-type(4) td:nth-of-type(2) span'), /staged/);
    t.match(await page.innerText('tbody tr:nth-of-type(5) td:nth-of-type(1) a'), /16862:curl/);
    t.match(await page.innerText('tbody tr:nth-of-type(5) td:nth-of-type(2) span'), /approved/);
  });

  await t.test('Incident details', async t => {
    await page.click('text=16860:perl-Mojolicious');
    await page.waitForURL('**/submission/16860');
    t.equal(page.url(), `${url}/submission/16860`);
    t.match(await page.innerText('.packages ul'), /perl-Mojolicious/);
    t.match(await page.innerText('.submission-results p'), /1\s*passed\s*1\s*failed\s*1\s*waiting/);
    t.equal(
      await page.locator('.submission-results a').first().getAttribute('href'),
      'https://openqa.suse.de/tests/overview?build=%3A16860%3Aperl-Mojolicious&not_group_glob=*Devel*%2C*Test*&result=ok'
    );

    await page.goto(`${url}/obsolete_jobs`);
    await page.goto(`${url}/submission/16860`);
    t.match(await page.innerText('.packages ul'), /perl-Mojolicious/);
    t.match(await page.innerText('.submission-results p'), /1\s*passed\s*1\s*waiting/);

    await page.goto(`${url}/reject_incident`);
    await page.goto(`${url}/submission/16860`);
    await page.waitForSelector('.alert-danger');
    t.match(await page.innerText('.alert-danger'), /Approval Rejected: missing aggregates/);
    t.ok(await page.isVisible('.fa-exclamation-circle.text-danger'));
    const iconTitle = await page.getAttribute('.fa-exclamation-circle.text-danger', 'title');
    t.equal(iconTitle, 'Rejected: missing aggregates');
  });

  await t.test('Sorting, highlighting and filtering on "Blocked" page', async t => {
    await page.goto(`${url}/blocked`);
    await page.waitForSelector('tbody');
    const list = page.locator('tbody > tr');
    t.equal(await list.count(), 3);
    t.match(await page.innerText('tbody tr:nth-of-type(1) td:nth-of-type(1) a'), /29722:multipath-tools/);
    t.match(await page.innerText('tbody tr:nth-of-type(1) td:nth-of-type(2)'), /SAP\/HA Maintenance 1\/5/);
    t.match(await page.innerText('tbody tr:nth-of-type(2) td:nth-of-type(1) a'), /16860:perl-Mojolicious/);
    t.match(await page.innerText('tbody tr:nth-of-type(2) td:nth-of-type(2)'), /SLE 12 SP5 1\/1/);
    t.match(await page.innerText('tbody tr:nth-of-type(3) td:nth-of-type(1) a'), /30000:gitea-pr/);
    t.match(await page.innerText('tbody tr:nth-of-type(3) td:nth-of-type(2)'), /No data yet/);
    t.match(await page.innerText('tbody tr.high-priority'), /29722:multipath-tools/);
    const pageUrl = await page.url();
    t.notMatch(pageUrl, /incident/);
    t.notMatch(pageUrl, /group_names/);
    t.notMatch(pageUrl, /group_flavors/);

    const search = page.getByPlaceholder('Search for submission/package');
    await search.fill('curl');
    await page.waitForFunction(() => document.querySelectorAll('tbody > tr').length === 0);
    t.equal(await list.count(), 0);
    t.match(await page.url(), /submission=curl/);

    await search.fill('perl');
    await page.waitForFunction(() => document.querySelectorAll('tbody > tr').length === 1);
    t.match(await page.innerText('tbody tr:nth-of-type(1) td:nth-of-type(2)'), /SLE 12 SP5 1\/1/);
    t.equal(await list.count(), 1);
    t.notMatch(await page.url(), /submission=curl/);
    t.match(await page.url(), /submission=perl/);

    const groupSearch = page.getByPlaceholder('Search for group names');
    await groupSearch.fill('SLE$');
    await page.waitForFunction(() => document.querySelectorAll('tbody > tr').length === 0);
    t.equal(await list.count(), 0);

    await groupSearch.fill('SLE 12 SP5');
    await page.waitForFunction(() => document.querySelectorAll('tbody > tr').length === 1);
    t.match(await page.innerText('tbody tr:nth-of-type(1) td:nth-of-type(2)'), /SLE 12 SP5 1\/1/);
    t.equal(await list.count(), 1);
    t.match(await page.url(), /submission=perl/);
    t.match(await page.url(), /group_names=SLE\+12\+SP5/);

    await groupSearch.fill('SLE 12 SP5$');
    await page.waitForFunction(() => location.href.includes('group_names=SLE+12+SP5%24'));
    t.match(await page.innerText('tbody tr:nth-of-type(1) td:nth-of-type(2)'), /SLE 12 SP5 1\/1/);
    t.equal(await list.count(), 1);

    await page.goto(`${url}/blocked?submission=foo&group_flavors=0&group_names=bar`);
    t.equal(await page.getByPlaceholder('Search for submission/package').inputValue(), 'foo');
    t.equal(await page.getByPlaceholder('Search for group names').inputValue(), 'bar');
    t.ok(!(await page.getByLabel('Group Flavors').isChecked()));
  });

  await t.test('Group blocked', async t => {
    await page.goto(`${url}/blocked`);
    await page.waitForSelector('tbody');
    t.match(await page.innerText('tbody tr:nth-of-type(1) td:nth-of-type(1) a'), /29722:multipath-tools/);
    t.match(await page.innerText('tbody tr:nth-of-type(1) td:nth-of-type(2)'), /SAP\/HA Maintenance 1\/5/);

    await page.getByLabel('Group Flavors').uncheck();
    await page.locator('tbody tr:nth-of-type(1) td:nth-of-type(2)', {hasText: 'SAP/HA Maintenance 1/3'}).waitFor();
    t.match(await page.innerText('tbody tr:nth-of-type(1) td:nth-of-type(1) a'), /29722:multipath-tools/);
    t.match(
      await page.innerText('tbody tr:nth-of-type(1) td:nth-of-type(2)'),
      /SAP\/HA Maintenance 1\/3.+Server-DVD-Incidents 12-SP6/s
    );

    await page.getByLabel('Group Flavors').check();
    await page.locator('tbody tr:nth-of-type(1) td:nth-of-type(2)', {hasText: 'SAP/HA Maintenance 1/5'}).waitFor();
    t.match(await page.innerText('tbody tr:nth-of-type(1) td:nth-of-type(1) a'), /29722:multipath-tools/);
    t.match(await page.innerText('tbody tr:nth-of-type(1) td:nth-of-type(2)'), /SAP\/HA Maintenance 1\/5/);
  });

  await t.test('Filtering by state on "Blocked" page', async t => {
    await page.goto(`${url}/blocked`);
    await page.waitForSelector('tbody');
    const list = page.locator('tbody > tr');
    t.equal(await list.count(), 3, 'All submissions are visible by default');

    t.ok(await page.getByLabel('failed').isChecked());
    t.ok(await page.getByLabel('accepted').isChecked());
    t.ok(await page.getByLabel('stopped').isChecked());
    t.ok(await page.getByLabel('waiting').isChecked());
    t.notOk(await page.getByLabel('passed').isChecked());

    t.ok(await page.isVisible('text=SAP/HA Maintenance 1/5'));
    t.ok(await page.isVisible('text=SLE 12 SP5 1/1'));

    await page.getByLabel('failed').uncheck();
    await page.getByText('SAP/HA Maintenance 1/5').waitFor({state: 'detached'});
    t.notOk(await page.isVisible('text=SAP/HA Maintenance 1/5'));
    t.ok(await page.isVisible('text=SLE 12 SP5 1/1'), 'waiting result stays visible while failed is filtered out');
    await page.waitForFunction(() => location.search.includes('states=accepted%2Cstopped%2Cwaiting'));
    t.match(await page.url(), /states=accepted%2Cstopped%2Cwaiting/);

    await page.getByLabel('passed').check();
    await page.waitForFunction(() => location.search.includes('states=accepted%2Cstopped%2Cwaiting%2Cpassed'));
    t.match(await page.url(), /states=accepted%2Cstopped%2Cwaiting%2Cpassed/);

    await page.getByLabel('failed').check();
    await page.getByLabel('passed').uncheck();
    await page.waitForFunction(() => !location.search.includes('states='));
    t.notMatch(await page.url(), /states=/);
  });

  await t.test('Incident popup', async t => {
    await page.goto(`${url}/repos`);
    await page.waitForSelector('tbody tr');
    await page
      .locator('tr:has-text("Server-DVD-Incidents-12-SP5-x86_64")')
      .getByRole('button', {name: /Submissions/})
      .click();
    await page.waitForSelector('#update-submissions', {state: 'visible'});
    await page.click('text=16860:perl-Mojolicious');
    await page.waitForURL('**/submission/16860');
    t.equal(page.url(), `${url}/submission/16860`);

    await page.click('text=Active');
    await page.locator('h1', {hasText: 'Active Incidents'}).waitFor();
    t.equal(await page.innerText('title'), 'Active Incidents');

    await page.goto(`${url}/incident/123`);
    await page.waitForSelector('#main-content p');
    t.equal(await page.innerText('#main-content p'), 'Submission does not exist.');
  });

  await t.test('Direct navigation to submission', async t => {
    await page.goto(`${url}/submission/16860`);
    await page.waitForSelector('.packages ul');
    t.equal(await page.innerText('title'), 'Details for Submission');
    t.match(await page.innerText('.packages ul'), /perl-Mojolicious/);
  });

  await t.test('Repos page detailed interactions', async t => {
    await page.goto(`${url}/repos`);
    await page.waitForSelector('tbody tr');
    const row = page.locator('tr:has-text("Server-DVD-Incidents-12-SP5-x86_64")');
    await t.test('Row is visible', async t => {
      await row.waitFor();
      t.ok(await row.isVisible());
    });

    await row.getByRole('button', {name: /Submissions/}).click();
    await page.waitForSelector('#update-submissions', {state: 'visible'});
    t.match(await page.innerText('#update-submissions .modal-title'), /Server-DVD-Incidents-12-SP5-x86_64/);
    t.match(await page.innerText('#update-submissions .modal-body'), /16860:perl-Mojolicious/);
    t.match(await page.innerText('#update-submissions .modal-body'), /16861:perl-Minion/);

    await page.click('#update-submissions .btn-close');
    await page.waitForSelector('#update-submissions', {state: 'hidden'});
  });

  await t.test('API error handling', async t => {
    const errorsBefore = errorLogs.length;
    // Mock API error for the list call
    await page.route('**/app/api/list', route => route.fulfill({status: 500, body: 'Internal Server Error'}));
    await page.goto(url);
    // The app currently falls back to its empty state instead of surfacing the error
    await page.getByText('No active submissions').waitFor();
    t.match(await page.innerText('#main-content'), /No active submissions/);
    await page.unroute('**/app/api/list');
    // The console error logged for the mocked failure above is expected
    await page.waitForTimeout(100);
    errorLogs.splice(errorsBefore);
  });

  await t.test('Link to Smelt if there are no incidents', async t => {
    await page.goto(`${url}/deactivate_incidents`);
    for (const path of ['/', '/blocked']) {
      await page.goto(url + path);
      await page.waitForSelector('#main-content');
      t.match(await page.innerText('#main-content'), /No active submissions.*look at Smelt/, `link shown on ${path}`);
    }
  });

  if (errorLogs.length > 0) {
    t.fail(`Unexpected console errors found:\n${errorLogs.join('\n')}`);
  }

  await context.close();
  await browser.close();
  await server.close();
});
