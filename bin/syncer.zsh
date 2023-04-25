#!/usr/bin/env zsh
# vim: set filetype=zsh:

cd ~/podcasts/dead-rabbit-radio/episodes/

for node in node{01..05}; do
  cd ~/podcasts/dead-rabbit-radio/episodes/
  /usr/local/bin/rsync -avz *.{log,srt,txt} deploy@${node}:~/podcasts/dead-rabbit-radio/episodes/ ;
  /usr/local/bin/rsync -avz deploy@${node}:~/podcasts/dead-rabbit-radio/episodes/*.{srt,txt,log} . ;
done

cp -n *.{srt,txt} ~/projects/just3ws/fluffle/transcripts

cd ~/projects/just3ws/fluffle/transcripts

echo
echo '------------------------------------------'
echo

ls *.srt | wc -l

echo
echo '------------------------------------------'
echo

git add -A

git commit -am "Transcription update"

git push
