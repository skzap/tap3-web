npm run build
rm ../tap3.me/assets/*
rm ../tap3.me/index.html
rm ../tap3.me/404.html
cp ./dist/assets/* ../tap3.me/assets/
cp ./dist/bgs/* ../tap3.me/bgs/
cp ./dist/cards/* ../tap3.me/cards/
cp ./dist/index.html ../tap3.me/
cp ./dist/index.html ../tap3.me/404.html