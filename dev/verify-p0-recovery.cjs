const {chromium} = require('playwright');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const START = 'I think fewer meetings would help our team finish work sooner.';
const checks=[];
async function send(p,text) {
 await p.getByRole('textbox',{name:'Chat message',exact:true}).fill(text);
 await p.getByRole('button',{name:'Send message',exact:true}).click();
}
async function ready(p) {await p.locator('#status').filter({hasText:'ready for review'}).waitFor({timeout:60000}).catch(async e => {console.log(await p.locator('body').ariaSnapshot()); throw e;});}
async function download(p,name) {
 await p.locator('#toggle_record').click();
 const event = p.waitForEvent('download');
 await p.locator('#save').click();
 await (await event).saveAs(path.resolve('artifacts',name));
 await p.getByRole('button',{name:'Close drawer',exact:true}).click();
}
(async () => {
 const b = await chromium.launch({channel:'chrome',headless:true});
 try {
  const p = await b.newPage();
  await p.goto('http://127.0.0.1:3906');
  await send(p,START); await ready(p);
  await p.getByRole('button',{name:'Decline',exact:true}).click();
  await p.locator('#status').filter({hasText:/declined/i}).waitFor();
  await download(p,'p0-declined.json');
  checks.push('A streamed scripted suggestion can be declined without applying it.');
  await send(p,START); await ready(p);
  await p.getByRole('button',{name:'Apply interpretation',exact:true}).click();
  await p.locator('#status').filter({hasText:/applied/i}).waitFor();
  await download(p,'p0-before-cancel.json');
  await send(p,'Fixture: cancel this slow response.');
  await p.waitForTimeout(2200);
  fs.writeFileSync('artifacts/p0-streaming-browser.txt',await p.locator('body').ariaSnapshot());
  const cancel = p.getByRole('button',{name:/Stop|Cancel/i});
  await cancel.click();
  await p.locator('#status').filter({hasText:/cancelled/i}).waitFor();
  await download(p,'p0-after-cancel.json');
  checks.push('Cancellation during the slow scripted turn leaves the retained interpretation intact.');
  await send(p,START); await ready(p);
  await p.getByRole('button',{name:'Apply interpretation',exact:true}).click();
  await p.locator('#status').filter({hasText:/applied/i}).waitFor();
  await download(p,'p0-after-retry.json');
  checks.push('Retry creates a fresh reviewable proposal and one explicit application.');
  await send(p,'By finish sooner I mean elapsed days from starting to completing a work item, next quarter. Keep coordination quality unchanged.');
  await ready(p);
  await p.getByRole('button',{name:'Correct',exact:true}).click();
  await p.locator('#correct_wording').fill('Fewer recurring meetings may shorten work-item completion time without harming coordination.');
  await p.locator('#correction_reason').fill('Keep the outcome and coordination constraint explicit.');
  await p.waitForTimeout(400);
  await p.locator('#apply_correction').click();
  await p.locator('#status').filter({hasText:/corrected|correction/i}).waitFor();
  await download(p,'p0-after-correction.json');
  checks.push('Human correction retains its reason and original suggestion provenance.');
  const u = await b.newPage({viewport:{width:390,height:844}});
  await u.goto('http://127.0.0.1:3908');
  await send(u,'Fewer meetings might help us finish work sooner.');
  await u.locator('#status').filter({hasText:/failed|stopped/i}).waitFor({timeout:60000});
  await u.locator('#toggle_record').click();
  await u.getByText('Edit the interpretation yourself',{exact:true}).click();
  await u.locator('#wording').fill('Fewer meetings might help us finish work sooner.');
  await u.locator('#target').fill('Elapsed days per completed work item');
  await u.locator('#scope').fill('Our team');
  await u.locator('#edit_reason').fill('Manual clarification while model access is unavailable');
  await u.waitForTimeout(400);
  await u.locator('#retain').click();
  await u.locator('#record_card').filter({hasText:'Elapsed days per completed work item'}).waitFor();
  const event = u.waitForEvent('download'); await u.locator('#save').click();
  await (await event).saveAs(path.resolve('artifacts/p0-unavailable-manual.json'));
  await u.screenshot({path:'artifacts/p0-unavailable-mobile.png'});
  checks.push('Unavailable model access leaves a working manual editor and downloadable non-numerical record at 390px.');
  fs.writeFileSync('artifacts/p0-recovery-browser.txt',checks.join('\n')+'\n');
  console.log(checks.join('\n'));
 } finally {await b.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
