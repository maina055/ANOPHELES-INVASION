# Verify the supplied file inventory before editing any project files.
# MD5 fingerprints detect file changes; they are not an authenticity signature.
manifest <- read.csv('CHECKSUMS.csv',stringsAsFactors=FALSE)
stopifnot(all(file.exists(manifest$file)),!anyDuplicated(manifest$file))
actual <- tools::md5sum(manifest$file)
stopifnot(identical(unname(actual),manifest$md5),
          all(file.info(manifest$file)$size==manifest$bytes))
cat('File inventory and fingerprints passed for ',nrow(manifest),' files.\n',sep='')
