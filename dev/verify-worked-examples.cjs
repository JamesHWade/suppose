const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
(async()=>{
 const browser=await chromium.launch({channel:'chrome',headless:true});
 const errors=[];
 const watch=p=>p.on('pageerror',e=>errors.push(e.message));
 try {
  const parent=await browser.newPage({viewport:{width:1280,height:950}});watch(parent);
  await parent.goto('http://127.0.0.1:3913');
  await parent.locator('#model_label').filter({hasText:'Local guide'}).waitFor();
  await parent.getByRole('button',{name:'Learn with worked examples',exact:true}).click();
  await parent.locator('.modal .worked-example-card').first().waitFor();
  assert.equal(await parent.locator('.modal .worked-example-card').count(),4);
  await parent.screenshot({path:'artifacts/worked-examples-gallery-desktop.png'});
  await parent.setViewportSize({width:390,height:844});
  await parent.screenshot({path:'artifacts/worked-examples-gallery-mobile.png'});
  assert.ok(await parent.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));
  await parent.getByRole('button',{name:'Back to my conversation'}).click();
  await parent.setViewportSize({width:1280,height:950});
  await parent.locator('#toggle_record').click();
  await parent.getByText('Edit the interpretation yourself',{exact:true}).click();
  await parent.locator('#wording').fill('My own inquiry must stay here.');
  await parent.waitForTimeout(350);await parent.locator('#retain').click();
  await parent.locator('#record_card').filter({hasText:'My own inquiry must stay here.'}).waitFor();
  await parent.locator('#wording').fill('An unsaved draft must stay here too.');
  await parent.locator('#toggle_record').click();
  await parent.locator('#open_examples').click();
  const slugs=['meetings','strength','plants','regression'];
  for(let i=0;i<slugs.length;i++) {
   const popup=parent.waitForEvent('popup');
   await parent.locator('.modal').getByRole('link',{name:`Open example ${i+1} in new tab`,exact:true}).click();
   const p=await popup;watch(p);
   assert.ok(p.url().includes(`suppose_example=${slugs[i]}`));
   await p.getByText('This is your own example copy.',{exact:false}).first().waitFor({timeout:60000});
   await p.screenshot({path:`artifacts/worked-example-${slugs[i]}-chat.png`});
   await p.locator('#toggle_record').click();
   await p.locator('#record_card').filter({hasText:'Retained interpretation'}).waitFor();
   if(slugs[i]==='meetings') {
    await p.getByText('Edit the interpretation yourself',{exact:true}).click();
    await p.locator('#horizon').fill('Next six weeks');
    await p.locator('#edit_reason').fill('Try a longer comparison for this tutorial.');
    await p.waitForTimeout(350);await p.locator('#retain').click();
    await p.locator('#status').filter({hasText:'Interpretation retained'}).waitFor();
   } else if(slugs[i]==='strength') {
    await p.waitForFunction(()=>{const i=document.querySelector('#record_prior_plot img');return i?.complete&&i.naturalWidth>0&&!document.documentElement.classList.contains('shiny-busy');});
    await p.getByText('Possible outcomes',{exact:true}).click();
    await p.locator('#record_prior_plot_draw_summary').filter({hasText:'Realization 1 of'}).waitFor();
    await p.getByRole('button',{name:'Next realization',exact:true}).click();
    await p.locator('#record_prior_plot_draw_summary').filter({hasText:'Realization 2 of'}).waitFor();
   } else if(slugs[i]==='plants') {
    await p.getByText('Learn from measurements',{exact:true}).click();
    await p.getByText('Update of revision 2',{exact:true}).click();
    await p.locator('#learning-retained img').first().waitFor();
    await p.getByText('Check sensitivity',{exact:true}).click();
    await p.locator('#sensitivity-retained summary').first().click();
    await p.locator('#sensitivity-retained img').first().waitFor();
   } else {
    await p.getByText('Fit and compare models',{exact:true}).click();
    const reviews=p.locator('#regression-retained > details > summary');
    assert.equal(await reviews.count(),2);
    await reviews.nth(1).click();
    await p.locator('#regression-retained img:visible').first().waitFor();
   }
   await p.setViewportSize({width:390,height:844});
   await p.waitForTimeout(700);
   assert.ok(await p.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),slugs[i]+' mobile overflow');
   assert.equal(await p.locator('.shiny-output-error:visible').count(),0,slugs[i]+' output error');
   assert.match(await p.locator('#save_notice').textContent(),/Save before closing/);
   await p.screenshot({path:`artifacts/worked-example-${slugs[i]}-mobile.png`});
   const download=p.waitForEvent('download');await p.locator('#save').click();
   const file=path.resolve(`artifacts/worked-example-${slugs[i]}.json`);
   await (await download).saveAs(file);
   const record=JSON.parse(fs.readFileSync(file,'utf8'));
   assert.ok(String(record.conversation[0].text).includes('example copy'));
   if(slugs[i]==='meetings')assert.equal(String(record.revisions.at(-1).claim.horizon),'Next six weeks');
   await p.close();
  }
  await parent.getByRole('button',{name:'Back to my conversation'}).click();
  await parent.locator('#toggle_record').click();
  assert.equal(await parent.locator('#wording').inputValue(),'An unsaved draft must stay here too.');
  assert.ok((await parent.locator('#record_card').textContent()).includes('My own inquiry must stay here.'));
  assert.deepEqual(errors,[]);
  console.log('PASS: four gallery links open independent guided records; original record and unsaved editor text survive; editing, draw stepping, retained update/sensitivity/regression plots, downloads, mobile layout and browser errors checked.');
 } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
