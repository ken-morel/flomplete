using Serialization:serialize, deserialize


const GARAVU = 50
const SHOWL = 2

"""
    struct Dictionary

Builds a word dictionaty for numbering words
"""
struct Dictionary 
  words::Vector{String}
end

Main.serialize(dict::Dictionary, txt::String)::Vector{Int} = filter(x -> x !== nothing, indexin(split(txt, r"\s"), dict.words))
Main.deserialize(dict::Dictionary, ser::Vector{Int})::String = join(" ", (x -> dict.words[x]).(ser))
function splittokens(txt)
    tokens = []
    regex = r"([a-zA-Zàâçéèêëîïôûùüÿñæœ]+|['’](?:s|t|re|ve|ll|d|m|on|en|y|jusqu|quoi|l|j|n|d|qu|c|m|t|s|p|z|ai|as|est|et|e|de)|[.!?~«»…,:;\"()\-\n])"
    for m in eachmatch(regex, txt)
        token = m.match
        if occursin(r"^[a-zA-Z]+$", token)
            push!(tokens, lowercase(token))
        else
            push!(tokens, token)
        end
    end
    tokens
end

function get_train_words(directory::String = "./train/fr")::Vector{String}
  words = Vector{String}()
  for filename in readdir(directory)
      println("File $filename")
      filepath = joinpath(directory, filename)
      isfile(filepath) || continue  # Skip directories
      open(filepath) do f
          content = replace(read(f, String), "\n" => " ")
          tokens = splittokens(content)
          filtered = filter(w -> length(w) > 0, tokens)
          append!(words, filtered)
      end
  end
  println("Got $(length(words)) tokens!")
  return words
end

function buildtrain()
  dict = loaddict()
  words = get_train_words()
  train = indexin(words, dict.words)
  open("./train.jls", "w") do f
    serialize(f, train)
  end
  train
end

function loadtrain()
  open("./train.jls") do f
    deserialize(f)
  end
end

function build_dictionary()::Dictionary
  save(Dictionary(sort(unique(get_train_words()))))
end

function save(dict::Dictionary)
  open("./dict.jls", "w") do f
    serialize(f, dict.words)
  end
  dict
end

function loaddict()::Dictionary
  open("./dict.jls") do f
    Dictionary(deserialize(f))
  end
end


function buildleading()
  train = loadtrain()
  leading::Vector{Tuple{Vector{Int}, Int}} = Vector()
  println("building train")
  for i ∈ (GARAVU + 1):length(train)
    push!(leading, (train[i - GARAVU:i - 1], train[i]))
  end
  open("./leading.jls", "w") do f
    serialize(f, leading)
  end
  println("build up to $(length(leading)) leading.")
  leading
end
function loadleading()
  open("./leading.jls") do f
    deserialize(f)
  end
end

sintersect(v::Tuple) = intersect(v...)

function match_difference(pattern::Vector{Int}, test::Vector{Int})::Float64
  o = length(pattern) - 1
  gpow(x) = x-o
  sum(enumerate(zip(pattern, test))) do (idx, (p, t))
    Float64(t != p) * ((80/100) ^ gpow(idx)) # give higher scores to last matches to work easily with infinite contexts
  end
end

function main(cmd::String)
  println("Executing command: $cmd")
  if cmd == "build-dict"
    @time (dict = build_dictionary())
    print("Created dict with $(length(dict.words)) words. $(dict.words[1:SHOWL])")
  elseif cmd == "build-train"
    train = @time buildtrain()
    println("Built train with $(length(train)) words $(train[1:SHOWL])")
  elseif cmd == "build-leading"
    leading = @time buildleading()
    println("Got $(length(leading)) of leading words")
  elseif cmd == "do"
    @time main.(["build-dict", "build-train", "build-leading"]) #, "optimize-leading"
  elseif cmd == "serialize"
    println(@time begin 
      dict = loaddict()
      serialize(dict, ARGS[2])
    end)
  elseif cmd == "optimize-leading"
    @time optimizeleading()
  elseif cmd == "deserialize"
    println(@time begin 
      dict = loaddict()
      deserialize(dict, (@__MODULE__).eval(Meta.parse(ARGS[2]))::Vector{Int})
    end)
  else
    println("ERROR: wrong command '$cmd'")
  end
end
function adjust_array(arr)
    len = length(arr)
    if len < GARAVU
        return vcat(zeros(Int, GARAVU - len),arr)
    elseif len > GARAVU
        return arr[(end - GARAVU + 1):end]
    else
        return copy(arr)
    end
end

function whatnext(values::Vector{Int})::Int
  values = adjust_array(values)
  data = loadleading()
  matches::Vector{Tuple{Float64, Int}} = Vector()
  min_match = nothing
  for (leading, word) ∈ data
    λ = match_difference(leading, values)
    if λ == 0 && rand() > 0.0
      return word
    end
    if min_match == nothing
      min_match = λ
    elseif min_match > λ
      empty!(matches)
      min_match = λ
    elseif min_match < λ
      continue
    end
    push!(matches, (λ, word))
  end
  sort!(matches)
  if length(matches) == 0
    0
  else
    rand(matches)[2]
  end
end




function complete(text::String)
  dict = loaddict()
  nxt = whatnext(serialize(dict, text))
  if nxt > 0
    text * " " * dict.words[nxt]
  else
    return text
  end
end




function speak(txt)
  run(`espeak -v fr "$txt"`)
end

function flomplete(txt::String, max::Int = 100)::String
  for _ in 1:max
    next = complete(txt)
    endswith(next, "~") && break
    if strip(next) == strip(txt)
      break
    end
    txt = next
    print(repr(txt) * "\r")
  end
  txt
end



if (@__MODULE__) == Main
  if length(ARGS) >= 1
    cmd = ARGS[1]
    main(cmd)
  else
    print("Enter query\n> ")
    txt = readline(stdin)
    speak(flomplete(txt))
  end
end

