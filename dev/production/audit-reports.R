# Real render acceptance: requires pandoc and TeX; never substitutes a mock.
pkgload::load_all(quiet=TRUE)
out<-Sys.getenv('PRESSR_ACCEPTANCE_OUT');stopifnot(nzchar(out),!dir.exists(out));dir.create(out,recursive=TRUE)
# Private recordings are inspected only when the caller explicitly opts in.
root<-Sys.getenv('PRESSR_DATA_ROOT')
trials<-list(generic=pr_example_trial('custom'),saddle=pr_example_trial('saddle_horse'),foot=pr_example_trial('insole'))
real<-if(nzchar(root)) list.files(file.path(root,'shared-data/raw_data'),pattern='[.]asc$',recursive=TRUE,full.names=TRUE) else character()
if(length(real)) trials$novel<-pr_read_auto(real[which.min(file.info(real)$size)],verbose=FALSE)
results<-list()
for(name in names(trials)) for(format in c('html','pdf')) {
  template<-if(name=='novel') 'saddle' else name
  path<-file.path(out,paste0(name,'.',format))
  template_path<-system.file('templates',paste0('report_',template,'.Rmd'),package='pressR')
  before<-digest::digest(template_path,algo='sha256',file=TRUE)
  masks<-if(name=='novel') pr_mask_rowbands(trials[[name]]$layout,c(5,11)) else NULL
  t<-system.time(pr_export_report(trials[[name]],path,format,template,masks=masks))
  stopifnot(file.exists(path),file.info(path)$size>1000,
            identical(before,digest::digest(template_path,algo='sha256',file=TRUE)))
  results[[paste(name,format)]]<-list(bytes=file.info(path)$size,elapsed=unname(t[3]),sha256=digest::digest(path,algo='sha256',file=TRUE))
  cat(name,format,'PASS',t[3],'seconds\n');flush.console()
}
jsonlite::write_json(results,file.path(out,'SUMMARY.json'),pretty=TRUE,auto_unbox=TRUE)
