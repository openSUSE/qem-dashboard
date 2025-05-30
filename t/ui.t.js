#!/usr/bin/env node
import {UserAgent} from '@mojojs/core';
import ServerStarter from '@mojolicious/server-starter';
import {chromium} from 'playwright';
import t from 'tap';

// eslint-disable-next-line no-undef
const env = process.env;
const skip = env.TEST_ONLINE === undefined ? {skip: 'set TEST_ONLINE to enable this test'} : {};

// Wrapper script with fixtures can be found in "t/wrappers/ui.pl"
t.test('Test dashboard ui', skip, async t => {
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
    t.equal(page.url(), `${url}/blocked`);
    t.equal(await page.innerText('title'), 'Blocked by Tests');

    await page.click('text=Repos');
    t.equal(page.url(), `${url}/repos`);
    t.equal(await page.innerText('title'), 'Test Repos');

    await page.click('text=Active');
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
    t.match(await page.innerText('tbody tr:nth-of-type(4) td:nth-of-type(1) a'), /16862:curl/);
    t.match(await page.innerText('tbody tr:nth-of-type(4) td:nth-of-type(2) span'), /approved/);
  });

  await t.test('Incident details', async t => {
    await page.click('text=16860:perl-Mojolicious');
    t.equal(page.url(), `${url}/incident/16860`);
    t.match(await page.innerText('.packages ul'), /perl-Mojolicious/);
    t.match(await page.innerText('.incident-results mark'), /1 passed, 1 failed, 1 waiting/);
    t.equal(
      await page.locator('text=openqa').getAttribute('href'),
      'https://openqa.suse.de/tests/overview?build=%3A17063%3Aperl-Mojolicious'
    );

    await page.goto(`${url}/obsolete_jobs`);
    await page.goto(`${url}/incident/16860`);
    await page.click('text=230066:perl-Mojolicious');
    t.match(await page.innerText('.packages ul'), /perl-Mojolicious/);
    t.match(await page.innerText('.incident-results mark'), /1 passed, 1 waiting/);
  });

  await t.test('Sorting, highlighting and filtering on "Blocked" page', async t => {
    await page.goto(`${url}/blocked`);
    await page.waitForSelector('tbody');
    const list = page.locator('tbody > tr');
    t.equal(await list.count(), 2);
    t.match(await page.innerText('tbody tr:nth-of-type(1) td:nth-of-type(1) a'), /29722:multipath-tools/);
    t.match(await page.innerText('tbody tr:nth-of-type(1) td:nth-of-type(2)'), /SAP\/HA Maintenance 1\/5/);
    t.match(await page.innerText('tbody tr:nth-of-type(2) td:nth-of-type(1) a'), /16860:perl-Mojolicious/);
    t.match(await page.innerText('tbody tr:nth-of-type(2) td:nth-of-type(2)'), /SLE 12 SP5 1/);
    t.match(await page.innerText('tbody tr.high-priority'), /29722:multipath-tools/);
    const pageUrl = await page.url();
    t.notMatch(pageUrl, /incident/);
    t.notMatch(pageUrl, /group_names/);
    t.notMatch(pageUrl, /group_flavors/);

    await page.fill('[placeholder="Search for incident/package"]', 'curl');
    t.equal(await list.count(), 0);
    t.match(await page.url(), /incident=curl/);

    await page.fill('[placeholder="Search for incident/package"]', 'perl');
    t.match(await page.innerText('tbody tr:nth-of-type(1) td:nth-of-type(2)'), /SLE 12 SP5 Kernel/);
    t.equal(await list.count(), 1);
    t.notMatch(await page.url(), /incident=curl/);
    t.match(await page.url(), /incident=perl/);

    await page.fill('[placeholder="Search for group names"]', 'SLE$');
    t.equal(await list.count(), 0);

    await page.fill('[placeholder="Search for group names"]', 'SLE 12 SP5');
    t.match(await page.innerText('tbody tr:nth-of-type(1) td:nth-of-type(2)'), /SLE 12 SP5/);
    t.match(await page.innerText('tbody tr:nth-of-type(1) td:nth-of-type(2)'), /SLE 12 SP5 Kernel/);
    t.equal(await list.count(), 1);
    t.match(await page.url(), /incident=perl/);
    t.match(await page.url(), /group_names=SLE\+12\+SP5/);

    await page.fill('[placeholder="Search for group names"]', 'SLE 12 SP5$');
    t.match(await page.innerText('tbody tr:nth-of-type(1) td:nth-of-type(2)'), /SLE 12 SP5/);
    t.notMatch(await page.innerText('tbody tr:nth-of-type(1) td:nth-of-type(2)'), /SLE 12 SP5 Kernel/);
    t.equal(await list.count(), 1);

    await page.goto(`${url}/blocked?incident=foo&group_flavors=0&group_names=bar`);
    t.equal(await page.getByPlaceholder('Search for incident/package').inputValue(), 'foo');
    t.equal(await page.getByPlaceholder('Search for group names').inputValue(), 'bar');
    t.ok(!(await page.getByLabel('Group Flavors').isChecked()));
  });

  await t.test('Group blocked', async t => {
    await page.goto(`${url}/blocked`);
    await page.waitForSelector('tbody');
    t.match(await page.innerText('tbody tr:nth-of-type(1) td:nth-of-type(1) a'), /29722:multipath-tools/);
    t.match(await page.innerText('tbody tr:nth-of-type(1) td:nth-of-type(2)'), /SAP\/HA Maintenance 1\/5/);

    await page.getByLabel('Group Flavors').uncheck();
    await page.waitForSelector('tbody');
    t.match(await page.innerText('tbody tr:nth-of-type(1) td:nth-of-type(1) a'), /29722:multipath-tools/);
    t.match(
      await page.innerText('tbody tr:nth-of-type(1) td:nth-of-type(2)'),
      /SAP\/HA Maintenance 1\/3.+SAP\/HA Maintenance 2/s
    );

    await page.getByLabel('Group Flavors').check();
    await page.waitForSelector('tbody');
    t.match(await page.innerText('tbody tr:nth-of-type(1) td:nth-of-type(1) a'), /29722:multipath-tools/);
    t.match(await page.innerText('tbody tr:nth-of-type(1) td:nth-of-type(2)'), /SAP\/HA Maintenance 1\/5/);
  });

  await t.test('Incident popup', async t => {
    await page.goto(`${url}/repos`);
    await page.click('text=2 Incidents');
    await page.click('text=16860:perl-Mojolicious');
    t.equal(page.url(), `${url}/incident/16860`);

    await page.click('text=Active');
    t.equal(await page.innerText('title'), 'Active Incidents');

    await page.goto(`${url}/incident/123`);
    t.equal(await page.innerText('.container p'), 'Incident does not exist.');
  });

  await t.test('Link to Smelt if there are no incidents', async t => {
    await page.goto(`${url}/deactivate_incidents`);
    for (const path of ['/', '/blocked']) {
      await page.goto(url + path);
      await page.waitForSelector('.container');
      t.match(await page.innerText('.container'), /No active incidents.*look at Smelt/, `link shown on ${path}`);
    }
  });

  t.same(errorLogs, []);

  await context.close();
  await browser.close();
  await server.close();
});
