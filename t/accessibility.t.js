#!/usr/bin/env node
// Copyright SUSE LLC
// SPDX-License-Identifier: GPL-2.0-or-later
import {UserAgent} from '@mojojs/core';
import ServerStarter from '@mojolicious/server-starter';
import {chromium} from 'playwright';
import AxeBuilder from '@axe-core/playwright';
import t from 'tap';

// eslint-disable-next-line no-undef
const env = process.env;
const skip = env.TEST_ONLINE === undefined ? {skip: 'set TEST_ONLINE to enable this test'} : {};

t.test('Accessibility audits', {skip, timeout: 60000}, async t => {
  const server = await ServerStarter.newServer();
  await server.launch('perl', ['t/wrappers/ui.pl']);
  const browser = await chromium.launch(env.TEST_HEADLESS === '0' ? {headless: false} : {});
  const context = await browser.newContext();
  const page = await context.newPage();
  const url = server.url();

  const errorLogs = [];
  page.on('console', message => {
    if (message.type() === 'error') {
      errorLogs.push(message.text());
    }
  });

  // Wait for the server to be ready
  const ua = new UserAgent();
  await ua.get(url, {timeout: 10000}).catch(error => console.warn(error));

  const checkAccessibility = async name => {
    await t.test(`Audit ${name}`, async t => {
      try {
        const results = await new AxeBuilder({page}).analyze();
        t.equal(results.violations.length, 0, `Should have no accessibility violations on ${name}`);
        if (results.violations.length > 0) {
          console.log(`Violations on ${name}:`, JSON.stringify(results.violations, null, 2));
        }
      } catch (error) {
        t.fail(`Failed to analyze ${name}: ${error.message}`);
      }
    });
  };

  try {
    await page.goto(url, {waitUntil: 'networkidle'});
    await page.waitForSelector('.navbar', {timeout: 5000});
    await checkAccessibility('Active Incidents (Home)');

    await page.click('text=Blocked');
    await page.waitForSelector('tbody tr', {timeout: 5000});
    await checkAccessibility('Blocked by Tests');

    await page.click('text=Repos');
    await page.waitForSelector('tbody', {timeout: 5000});
    await checkAccessibility('Test Repos');

    await page.goto(`${url}/incident/16860`, {waitUntil: 'networkidle'});
    await page.waitForSelector('.details', {timeout: 5000});
    await checkAccessibility('Incident Details');
  } catch (error) {
    t.fail(`Navigation or selection failed: ${error.message}`);
  }

  if (errorLogs.length > 0) {
    t.fail(`Unexpected console errors found:\n${errorLogs.join('\n')}`);
  }

  await context.close();
  await browser.close();
  await server.close();
});
