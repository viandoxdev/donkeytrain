# donkeytrain - a script to train donkeycar ai

## How to use

clone this repository

```bash
git clone https://github.com/viandoxdev/donkeytrain
cd donkeytrain
```

run setup

```bash
./train.sh setup
```

> This script should always be ran from the directory that it is in.

use the script

## Examples

get the data from the car, train it, and upload the model bash to the car

```bash
./train.sh download foo # download car data to data/foo
./train.sh run data/foo bar # train model bar from foo (models/bar)
./train.sh upload bar
```

## More

see the help (and help config) command for more

```bash
./train.sh help
```
```bash
./train.sh help config
```

