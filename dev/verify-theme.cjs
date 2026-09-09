const {chromium}=require('playwright');
const assert=require('node:assert/strict');
(async()=>{
 const b=await chromium.launch({channel:'chrome',headless:true});
 try{
  const p=await b.newPage({viewport:{width:1280,height:900}});
  await p.goto('http://127.0.0.1:3905');
  await p.locator('.suppose-brand-mark').waitFor();
  await p.waitForTimeout(1500);
  assert.equal(await p.locator('.suppose-brand-mark').evaluate(e=>e.complete&&e.naturalWidth>0),true);
  await p.screenshot({path:'artifacts/theme-desktop.png'});
  await p.setViewportSize({width:390,height:844});
  await p.screenshot({path:'artifacts/theme-mobile.png'});
  assert.ok(await p.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));
  await p.locator('#toggle_record').click();
  await p.getByText('Edit the interpretation yourself',{exact:true}).click();
  await p.locator('#wording').fill('I think clearer instructions would help.');
  await p.waitForTimeout(350);
  await p.locator('#retain').click();
  await p.locator('#record_card').filter({hasText:'clearer instructions'}).waitFor();
  await p.screenshot({path:'artifacts/theme-record-mobile.png'});
  console.log('Sticker loads; desktop/mobile render; no 390px horizontal overflow; manual record editing works.');
 }finally{await b.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
