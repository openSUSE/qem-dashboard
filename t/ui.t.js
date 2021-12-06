#!/usr/bin/env node
import ServerStarter from '@mojolicious/server-starter';
import {chromium} from 'playwright';
import t from 'tap';

const skip = process.env.TEST_ONLINE === undefined ? {skip: 'set TEST_ONLINE to enable this test'} : {};

// Wrapper script with fixtures can be found in "t/wrappers/ui.pl"
t.test('Test dashboard ui', skip, async t => {
  const server = await ServerStarter.newServer();
  await server.launch('perl', ['t/wrappers/ui.pl']);
  const browser = await chromium.launch(process.env.TEST_HEADLESS === '0' ? {headless: false, slowMo: 500} : {});
  const context = await browser.newContext();
  const page = await context.newPage();
  const url = server.url();

  await t.test('Navigation', async t => {
    await page.goto(url);
    t.equal(await page.innerText('title'), 'Active Incidents');
    await page.click('text=Blocked');

    t.equal(page.url(), url + '/blocked');
    t.equal(await page.innerText('title'), 'Blocked by Tests');
    await page.click('text=Repos');

    t.equal(page.url(), url + '/repos');
    t.equal(await page.innerText('title'), 'Test Repos');
  });

  await t.test('Overview', async t => {
    await page.goto(url);
    t.match(await page.innerText('tbody tr:nth-of-type(1) td:nth-of-type(1) a'), /16860:perl-Mojolicious/);
    t.match(await page.innerText('tbody tr:nth-of-type(1) td:nth-of-type(2) span'), /testing/);
    t.match(await page.innerText('tbody tr:nth-of-type(2) td:nth-of-type(1) a'), /16861:perl-Minion/);
    t.match(await page.innerText('tbody tr:nth-of-type(2) td:nth-of-type(2) span'), /staged/);
    t.match(await page.innerText('tbody tr:nth-of-type(3) td:nth-of-type(1) a'), /16862:curl/);
    t.match(await page.innerText('tbody tr:nth-of-type(3) td:nth-of-type(2) span'), /approved/);
  });

  await context.close();
  await browser.close();
  await server.close();
});
