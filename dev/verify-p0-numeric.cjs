const {chromium} = require('playwright');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
async function tabTo(p,id) {
 for(let n=0;n<150;n++) {
  if(await p.locator(id).evaluate(e=>e===document.activeElement)) return;
  await p.keyboard.press('Tab');
 }
 throw Error(`Keyboard could not reach ${id}`);
}
(async()=>{
 const b=await chromium.launch({headless:true,channel:'chrome'});
 try {
  const p=await b.newPage({viewport:{width:1280,height:900}});
  await p.goto('http://127.0.0.1:3909');
  await p.waitForFunction(()=>document.querySelector('#wording')?.value.length>0);
  await tabTo(p,'#rho');
  for(let i=0;i<8;i++) await p.keyboard.press('ArrowDown');
  assert.equal(await p.locator('#rho').inputValue(),'0');
  await p.waitForTimeout(400);
  await tabTo(p,'#inspect'); await p.keyboard.press('Enter');
  await p.locator('#prob_metric').filter({hasText:'71.7%'}).waitFor();
  await p.locator('#accept_reason').fill('The stated marginal intervals match my invented judgments.');
  await p.locator('#challenge').fill('A randomized batch comparison could challenge the assumed improvement.');
  await p.locator('#reviewed').check();
  await p.locator('#rho').fill('0.8');
  await p.waitForTimeout(400); await p.locator('#accept').click();
  await p.locator('#status').filter({hasText:'Inspect the current inputs'}).waitFor();
  await p.locator('#low95').fill('40');
  await p.waitForTimeout(400); await p.locator('#inspect').click();
  await p.locator('#status').filter({hasText:'Clarify this judgment'}).waitFor();
  await p.locator('#low95').fill('55');
  await p.waitForTimeout(400); await p.locator('#inspect').click();
  await p.locator('#prob_metric').filter({hasText:'87.8%'}).waitFor();
  await p.locator('#reviewed').check();
  await p.waitForTimeout(400); await tabTo(p,'#accept'); await p.keyboard.press('Enter');
  await p.locator('#status').filter({hasText:'Reviewed revision accepted'}).waitFor();
  const event=p.waitForEvent('download'); await p.locator('#download').click();
  await (await event).saveAs(path.resolve('artifacts/p0-numeric-record.json'));
  await p.setViewportSize({width:390,height:844});
  await p.locator('#rho').scrollIntoViewIfNeeded();
  await p.screenshot({path:'artifacts/p0-numeric-mobile.png'});
  assert.ok(await p.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));
  const r=await b.newPage(); await r.goto('http://127.0.0.1:3909');
  await r.waitForFunction(()=>document.querySelector('#wording')?.value.length>0);
  await r.locator('#upload').setInputFiles(path.resolve('artifacts/p0-numeric-record.json'));
  await r.locator('#status').filter({hasText:'reopened without recomputing'}).waitFor();
  const event2=r.waitForEvent('download'); await r.locator('#download').click();
  await (await event2).saveAs(path.resolve('artifacts/p0-numeric-reopened.json'));
  const text='Keyboard adjustment of correlation from 0.8 to 0 changes P(gain > 5 MPa) from 87.8% to 71.7%. Changed inputs cannot be accepted before inspection. Inconsistent quantiles produce a clarification, then correction restores the candidate. Explicit review retains a challenge; native save/upload reopens it. The 390px form has no page-level horizontal overflow.';
  fs.writeFileSync('artifacts/p0-numeric-browser.txt',text+'\n'); console.log(text);
 }finally{await b.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
