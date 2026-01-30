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

  // Wait for the server to be ready
  const ua = new UserAgent();
  await ua.get(url, {timeout: 10000}).catch(error => console.warn(error));

  const checkAccessibility = async name => {
    await t.test(`Audit ${name}`, async t => {
      const results = await new AxeBuilder({page}).analyze();
      t.equal(results.violations.length, 0, `Should have no accessibility violations on ${name}`);
      if (results.violations.length > 0) {
        console.log(`Violations on ${name}:`, JSON.stringify(results.violations, null, 2));
      }
    });
  };

  await page.goto(url);
  await page.waitForSelector('.navbar');
  await checkAccessibility('Active Incidents (Home)');

  await page.click('text=Blocked');
  await page.waitForSelector('tbody tr');
  await checkAccessibility('Blocked by Tests');

  await page.click('text=Repos');
  await page.waitForSelector('tbody');
  await checkAccessibility('Test Repos');

  await page.goto(`${url}/incident/16860`);
  await page.waitForSelector('.details');
  await checkAccessibility('Incident Details');

  await context.close();
  await browser.close();
  await server.close();
});
