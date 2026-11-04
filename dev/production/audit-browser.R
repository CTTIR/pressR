main <- function() {
library(pressR)
out<-Sys.getenv('PRESSR_ACCEPTANCE_OUT');stopifnot(nzchar(out),!dir.exists(out));dir.create(out,recursive=TRUE)
# Private recordings are inspected only when the caller explicitly opts in.
root<-Sys.getenv('PRESSR_DATA_ROOT')
files<-if(nzchar(root)) list.files(file.path(root,'shared-data/raw_data'),pattern='[.]asc$',recursive=TRUE,full.names=TRUE) else character()
source<-if(length(files)) files[which.max(file.info(files)$size)] else pr_example_files('insole')
expected<-pr_read_auto(source,verbose=FALSE)
app<-shinytest2::AppDriver$new(system.file('shiny','pressR',package='pressR'),
       name='production-browser',load_timeout=120000,timeout=120000,
       width=1440,height=1000,options=list(sass.cache=FALSE))
on.exit({
  try(saveRDS(app$get_logs(),file.path(out,'browser-logs.rds')),silent=TRUE)
  try(app$get_screenshot(file=file.path(out,'last-state.png')),silent=TRUE)
  app$stop()
},add=TRUE)
app$upload_file(upload=source,timeout_=120000)
info<-app$get_value(output='trial_info')
cat('UPLOAD INFO:',info,'\n');flush.console()
stopifnot(grepl(basename(source),info,fixed=TRUE) && grepl(paste('Frames:',expected$n_frames),gsub(',','',info,fixed=TRUE),fixed=TRUE))
app$get_screenshot(file=file.path(out,'import.png'))
# Upload the same recording under a second explicit identity for comparison.
app$upload_file(upload_b=source,timeout_=120000)
app$set_inputs(compare_type='difference')
app$run_js("document.querySelectorAll('a.nav-link').forEach(a=>{if(a.textContent.trim()==='Compare') a.click();})")
app$wait_for_idle(timeout=120000)
app$wait_for_js("document.querySelector('#compare_plot img')?.complete && document.querySelector('#compare_plot img')?.naturalWidth > 0 && document.querySelector('#compare_plot img')?.alt.includes('trial B minus trial A')",timeout=120000)
stopifnot(!nzchar(app$get_js("document.querySelector('#compare_plot .shiny-output-error')?.textContent || ''")))
app$get_screenshot(file=file.path(out,'comparison.png'))
# Download real outputs and compare the selected masks with direct computation.
selected_mask<-if(expected$layout$name=='saddle_novel') 'study_rowbands' else 'default'
app$set_inputs(mask_set=selected_mask,wait_=FALSE)
app$wait_for_js(paste0("Shiny.shinyapp.$inputValues.mask_set === ",jsonlite::toJSON(selected_mask,auto_unbox=TRUE)))
app$run_js("document.querySelectorAll('a.nav-link').forEach(a=>{if(a.textContent.trim()==='Report') a.click();})")
app$wait_for_idle(timeout=120000)
regional<-app$get_download('dl_regional',filename=file.path(out,'regional.csv'))
d<-readr::read_csv(file.path(out,'regional.csv'),show_col_types=FALSE)
masks<-if(expected$layout$name=='saddle_novel') pr_mask_rowbands(expected$layout,c(5,11)) else pr_mask_default(expected$layout)
ref<-pr_calc_regional(expected,masks)
stopifnot(identical(d$region,ref$region),max(abs(d$mpp-ref$mpp))<1e-9)
selected_template<-if(expected$layout$name=='saddle_novel') 'saddle' else 'foot'
app$set_inputs(report_template=selected_template,report_format='html',wait_=FALSE)
app$wait_for_js(paste0("Shiny.shinyapp.$inputValues.report_template === ",jsonlite::toJSON(selected_template,auto_unbox=TRUE)))
app$wait_for_idle(timeout=120000)
app$get_download('dl_report',filename=file.path(out,'report.html'))
stopifnot(file.info(file.path(out,'report.html'))$size>1000)
app$run_js("document.querySelectorAll('a.nav-link').forEach(a=>{if(a.textContent.trim()==='Temporal') a.click();})")
app$set_inputs(temporal_profile='corrected',wait_=FALSE);app$wait_for_idle(timeout=120000);app$click('run_temporal')
app$wait_for_idle(timeout=120000)
stopifnot(grepl('corrected',app$get_value(output='temporal_info'),fixed=TRUE))
app$get_screenshot(file=file.path(out,'temporal.png'))
bad<-file.path(out,'invalid.asc');writeLines('invalid pressure file',bad)
app$run_js("document.querySelectorAll('a.nav-link').forEach(a=>{if(a.textContent.trim()==='Import') a.click();})")
app$wait_for_idle(timeout=120000)
app$upload_file(upload=bad)
stopifnot(grepl('No trial loaded',app$get_value(output='trial_info'),fixed=TRUE))
saveRDS(app$get_logs(),file.path(out,'browser-logs.rds'))
jsonlite::write_json(list(status='pass',source_filename=basename(source),bytes=file.info(source)$size,frames=expected$n_frames,
                         upload=TRUE,comparison=TRUE,regional_download=TRUE,report_download=TRUE,temporal=TRUE,failed_upload_clears_state=TRUE),
                    file.path(out,'SUMMARY.json'),auto_unbox=TRUE,pretty=TRUE)
app$stop()

}
main()
