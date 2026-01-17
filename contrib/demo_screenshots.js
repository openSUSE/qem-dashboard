#!/usr/bin/env node
// Copyright SUSE LLC
// SPDX-License-Identifier: GPL-2.0-or-later
/* global process */
import ServerStarter from '@mojolicious/server-starter';
import {chromium} from 'playwright';
import path from 'path';
import {fileURLToPath} from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function run() {
  const server = await ServerStarter.newServer();
  // Using t/wrappers/ui.pl which provides mock data
  await server.launch('perl', [path.join(__dirname, '..', 't', 'wrappers', 'ui.pl')]);
  const browser = await chromium.launch();
  const context = await browser.newContext({viewport: {width: 1280, height: 720}});
  const page = await context.newPage();
  const url = server.url();

  console.log(`Server started at ${url}`);

  // Wait for the app to be ready
  await page.goto(url);
  await page.waitForSelector('.navbar');

  // Screenshot of Blocked page
  await page.goto(`${url}/blocked`);
  await page.waitForSelector('tbody tr');
  // Wait a bit for any icons/styles to load
  await page.waitForTimeout(1000);

  // Focus the skip link to show it in a screenshot
  await page.keyboard.press('Tab');
  await page.screenshot({path: 'demo_skip_link.png'});
  console.log('Saved demo_skip_link.png');

  await page.screenshot({path: 'demo_blocked.png', fullPage: true});
  console.log('Saved demo_blocked.png');

  // Screenshot of Incident details page (16860:perl-Mojolicious)
  await page.goto(`${url}/incident/16860`);
  await page.waitForSelector('.details');
  await page.waitForTimeout(1000);
  await page.screenshot({path: 'demo_incident.png', fullPage: true});
  console.log('Saved demo_incident.png');

  await context.close();
  await browser.close();
  await server.close();
}

run().catch(err => {
  console.error(err);
  process.exit(1);
});
