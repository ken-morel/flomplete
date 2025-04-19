# flomplete

Flomplete is a text completion tool created in julia! It simply tries to provide the next and next words until... you hit `ctrl+c` or the precised length was attained.

## usage and functioning principle

All starts with a local clone of the repo using git:

```bash
git clone https://github.com/ken-morel/flomplete.git
```

Github cli

```bash
gh repo clone ken-morel/flomplete
```

## model creation

This step is simply where the model does two things:
- *1*: Flomplete collects the text of all training files, the reading is not streamed so that may be very
  memory costly.
- *2*: It builds a `Dictionary` instance which will be used to map every word or punctuation to an integer
- *3*: Flomplete then uses `serialize` on on the input text and creates a list of *contextsize* preceding word, word tuples, which will be stored as a model.

all this is done using the command

```bash
julia main.jl buildmodel $workspace --contextsize 20
```

where contextsize is optional and workspace is the folder where flomplete will search for files without the '.jls' extention, the build the preceding, word pairs.

## chatting

When chatting, flomplete simply compares the current text with all those in the model database back to the contextsize. where every word before the last word counts `scalefactor`^pos where pos is the distance from last word. as such is `scalefactor` is 0.1, if 'what is', then a match with what counts 10 times less than a match with is.

```bash
julia main.jl chat $modelpath --scalefactor $n
```

Whate scalefactor is optional and modelpath is the path to the '.jls' model or the folder containing the 'model.jls' file(like the previous workspace folder).

## example



```bash
engon@jealomy ॐ  ~/flomplete:(7h26m|git:(main*) ⌚Apr 19 11:07:55
2504 ± julia main.jl buildmodel ./train/fr --contextsize 10                                                                                                     ✖ ✹ ✭
 - File: 2-et-2-font-cinq.txt
   Got 81247 words in 0.1369478702545166
 - File: compte-future.txt
   Got 7124 words in 0.009275197982788086
 - File: curiosite-judiciare.txt
   Got 14881 words in 0.014961957931518555
 - File: europe-en-amerique-par-le-pole-nord.txt
   Got 66430 words in 0.06365799903869629
 - File: haute-ethiopie.txt
   Got 209200 words in 0.2757868766784668
 - File: notes-sur-lamour.txt
   Got 63400 words in 0.057394981384277344
 - File: quand-la-terre-tremblera.txt
   Got 107444 words in 0.09432601928710938
   Finished collecting words.
 - building dictionary
   Built dictionary with up to 30919 words in 0.07870101928710938.
 - Serializing train dataset
   done in 0.07704901695251465
 - Building ~model~ word groups with context size 10
   Built model with 549716 word groups in 0.6852049827575684.
 - saving all of that
  Done in 1.7578351497650146 seconds, you're all set!
Total took
  4.559734 seconds (11.66 M allocations: 516.187 MiB, 8.74% gc time, 33.75% compilation time)
engon@jealomy ॐ  ~/flomplete:(7h27m|git:(main*) ⌚Apr 19 11:08:19
2505 ± julia main.jl chat ./train/fr                                                                                                                            ✖ ✹ ✭
Loaded model with 549716 tokens, 30919 words and 10 context.
> je penses que
je penses que mon cheval était encore fatigué de son voyage de gondar . - - et quand tu lui donnerais la fourbure , reprit - il , tu crois que monseigneur n a pas dequoi te dédommager ? cet homme ne me dit pas qu il était envoyé par Oubié , et je venais sans le savoir d indisposer le dedjazmatch . en arrivant à l étape , le dedjazmatch me fit inviter à son repas , ainsi qu un botaniste européen , venu comme moi d adwa pour lui faire escorte . la réunion était nombreuse , et tout se
>
```
```
```



-- Data in train directory from [GuttenBergs project](https://gutenberg.org)

