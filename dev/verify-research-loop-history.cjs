const {chromium}=require('playwright');
const fs=require('node:fs');
const path=require('node:path');
const assert=require('node:assert/strict');
(async()=>{
 const browser=await chromium.launch({channel:'chrome',headless:true});
 const page=await browser.newPage({viewport:{width:1360,height:960}});
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 try {
  const id=fs.readFileSync('artifacts/research-loop-native-id.txt','utf8').trim();
  await page.goto(`http://127.0.0.1:3914/?shinychat_conversation_id=${id}`);
  await page.locator('#status').filter({hasText:'record restored'}).waitFor({timeout:60000});
  await page.locator('#toggle_record').click();
  await page.locator('#regression_test-panel>summary').click();
  await page.locator('#regression_test-retained').filter({hasText:'Fictional fixed-time'}).waitFor();
  const event=page.waitForEvent('download');await page.locator('#save').click();
  const file=path.resolve('artifacts/research-loop-reopened.json');await(await event).saveAs(file);
  const reopened=JSON.parse(fs.readFileSync(file,'utf8'));
  const before=JSON.parse(fs.readFileSync('artifacts/research-loop-final.json','utf8'));
  for(const key of ['research_designs','regression_commitments','regression_test_data','regression_assessments','regression_sensitivities'])assert.deepEqual(reopened[key],before[key],key);
  assert.equal(await page.locator('.shiny-output-error:visible').count(),0);
  await page.locator('#regression_test-retained>details>summary').click();
  await page.screenshot({path:'artifacts/research-loop-reopened-desktop.png'});
  await page.locator('#regression_sensitivity-panel>summary').click();
  await page.locator('#regression_sensitivity-retained>details>summary').click();
  const comparison=page.locator('#regression_sensitivity-retained .table-responsive');
  await comparison.scrollIntoViewIfNeeded();
  await page.screenshot({path:'artifacts/research-loop-comparison-desktop.png'});
  for(const width of [1360,390]) {
    await page.setViewportSize({width,height:960});
    await comparison.scrollIntoViewIfNeeded();
    const bounds=await page.locator('.inquiry-record').evaluate(el=>({width:el.clientWidth,scroll:el.scrollWidth}));
    if(bounds.scroll>bounds.width+1) console.log(await page.locator(".inquiry-record").evaluate(root=>[...root.querySelectorAll("*")].filter(e=>!e.closest(".table-responsive") && e.getBoundingClientRect().right>root.getBoundingClientRect().right+1).map(e=>({tag:e.tagName,id:e.id,cls:e.className,w:e.getBoundingClientRect().width,text:e.textContent.slice(0,60)})).slice(0,25)));
    assert.ok(bounds.scroll<=bounds.width+1,JSON.stringify(bounds));
    await page.screenshot({path:`artifacts/research-loop-comparison-${width}.png`});
  }
  assert.deepEqual(errors,[]);
  console.log('PASS native URL reopening retains both plans, frozen predictions, all evidence/assessment versions, and sensitivity reviews exactly.');
 }catch(e){await page.screenshot({path:'artifacts/research-loop-history-failure.png'});fs.writeFileSync('artifacts/research-loop-history-failure.txt',await page.locator('body').ariaSnapshot());throw e;}finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
