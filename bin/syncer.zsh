#!/usr/bin/env zsh
# vim: set filetype=zsh:

mkdir -p ~/podcasts/dead-rabbit-radio/episodes/
cd ~/podcasts/dead-rabbit-radio/episodes/

for node in node{01..05}; do
  cd ~/podcasts/dead-rabbit-radio/episodes/

  # /usr/local/bin/rsync -avz *.{log,srt,txt,vtt} deploy@${node}:~/podcasts/dead-rabbit-radio/episodes/ ;
  # /usr/local/bin/rsync -avz deploy@${node}:~/podcasts/dead-rabbit-radio/episodes/**/*.{log,srt,txt,vtt,.*} . ;
  /usr/local/bin/rsync -avz \
    --include '*/' \
    --include='*.txt' \
    --include='*.vtt' \
    --include='*.log' \
    --include='*.srt' \
    --include='.*' \
    --exclude='*' deploy@${node}:~/podcasts/dead-rabbit-radio/episodes/ ~/podcasts/dead-rabbit-radio/episodes/
done

# cp -n *.{srt,txt} ~/projects/just3ws/fluffle/transcripts

# cd ~/projects/just3ws/fluffle/transcripts

echo
echo '------------------------------------------'
echo

# ls *.srt | wc -l

echo
echo '------------------------------------------'
echo

# git add -A
#
# git commit -am "Transcription update"
#
# git push
