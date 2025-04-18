using Serialization:serialize, deserialize

const GARAVU = 20
const THRESHOLD = 5

"""
    struct Dictionary

Builds a word dictionaty for numbering words
"""
struct Dictionary 
  words::Vector{String}
end

Main.serialize(dict::Dictionary, txt::String)::Vector{Int} = filter(x -> x !== nothing, indexin(split(txt, r"\s"), dict.words))
Main.deserialize(dict::Dictionary, ser::Vector{Int})::String = join(" ", (x -> dict.words[x]).(ser))

function get_train_words()::Vector{String}
  open("./shakespeare.txt") do f
    filter(split(lowercase(read(f, String)[1:500]), r"\s")) do w
      length(w) > 0
    end
  end
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
  leading::Vector{Tuple{Vector{Vector{Int}}, Vector{Int}}} = Vector()
  for i ∈ (GARAVU + 1):(length(train) - 1)
    push!(leading, ([[i] for i in train[i - GARAVU:i]], [train[i+1]]))
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

function difference(a::Vector{Vector{Int}}, b::Vector{Vector{Int}})::Int
  return count(iszero ∘ length ∘ sintersect, zip(a, b))
end

function merge!(arr1::Vector{Vector{Int}}, arr2::Vector{Vector{Int}})
  for idx ∈ 1:min(length(arr2), length(arr1))
    push!.([arr1[idx]], arr2[idx])
    unique!(arr1[idx])
  end
end

function optimizeleading()
  leading = loadleading()
  final = Vector()
  println("optimize one")
  count = 0
  for lidx ∈ 1:length(leading)
    count += 1
    found::Bool = false
    for fidx ∈ 1:length(final)
      if leading[lidx][1] == final[fidx][1]
        push!.([final[fidx][2]], leading[lidx][2])
        found = true
        break
      end
    end
    if !found
      push!(final, leading[lidx])
    end
    if count % 1000 == 0
      print("$(lidx / length(leading) * 100)%\r")
    end
  end
  println("uniques")
  for fidx ∈ 1:length(final)
    unique!(final[fidx][2])
  end
  println("Size reduced from $(length(leading)) to $(length(final)) in first opt.")
  open("./leading.o.jls", "w") do f
    serialize(f, final)
  end
  shortet = Vector()
  count = 0
  for (idx, (args, sargs)) ∈ enumerate(final)
    count += 1
    found = false
    for idx ∈ 1:length(shortet)
      if difference(shortet[idx][1], args) <= THRESHOLD && length(intersect(sargs, shortet[idx][2])) >= 1
        merge!(shortet[idx][1], args)
        found = true
      end
    end
    if !found 
      push!(shortet, (args, sargs))
    end
    if count % 100 == 0
      print("$(idx / length(final) * 100)%\r")
    end
  end


  println("Size reduced from $(length(final)) to $(length(shortet)) in second opt")

  open("./leading.oo.jls", "w") do f
    serialize(f, shortet)
  end
end

function main(cmd::String)
  println("Executing command: $cmd")
  if cmd == "build-dict"
    @time (dict = build_dictionary())
    print("Created dict with $(length(dict.words)) words. $(dict.words[1:20])")
  elseif cmd == "build-train"
    train = @time buildtrain()
    println("Built train with $(length(train)) words $(train[1:20])")
  elseif cmd == "build-leading"
    leading = @time buildleading()
    println("Got $(length(leading)) of leading words")
  elseif cmd == "do"
    @time main.(["build-dict", "build-train", "build-leading", "optimize-leading"])
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





function flomplete(text::String)
  dict = loaddict()
  text * " " * dict.words[what_next(serialize(dict, text))]
end



if (@__MODULE__) == Main
  if length(ARGS) >= 1
    cmd = ARGS[1]
  else
    println("Missing command")
  end
  main(cmd)
end
