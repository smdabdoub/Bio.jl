
# A Kmer is a sequence <= 32nt, without any 'N's, packed in a single 64 bit value.
#
# While NucleotideSequence is an efficient general-purpose sequence
# representation, Kmer is useful for applications like assembly, k-mer counting,
# k-mer based quantification in RNA-Seq, etc that rely on manipulating many
# short sequences as efficiently (space and time) as possible.
#

bitstype 64 Kmer{T <: Nucleotide, K}

typealias DNAKmer{K} Kmer{DNANucleotide, K}
typealias RNAKmer{K} Kmer{RNANucleotide, K}

typealias Codon RNAKmer{3}


# Conversion to/from Uint64
function convert{K}(::Type{DNAKmer{K}}, x::Uint64)
    return box(DNAKmer{K}, unbox(Uint64, x))
end

function convert{K}(::Type{RNAKmer{K}}, x::Uint64)
    return box(RNAKmer{K}, unbox(Uint64, x))
end

function convert(::Type{Uint64}, x::DNAKmer)
    return box(Uint64, unbox(DNAKmer, x))
end

function convert(::Type{Uint64}, x::RNAKmer)
    return box(Uint64, unbox(RNAKmer, x))
end


function convert{T}(::Type{Kmer{T}}, seq::String)
    k = length(seq)
    if k > 32
        error(string("Cannot construct a K-mer longer than 32nt."))
    end
    return convert(Kmer{T, k}, seq)
end


function convert{T, K}(::Type{Kmer{T, K}}, seq::String)
    if length(seq) != K
        error(string("Cannot construct a $(K)-mer from a string of length $(length(seq))"))
    end

    x = uint64(0)
    shift = 0
    for (i, c) in enumerate(seq)
        nt = convert(T, c)
        if nt == nnucleotide(T)
            error("A Kmer may not contain an N in its sequence")
        end
        x |= convert(Uint64, nt) << shift
        shift += 2
    end
    return convert(Kmer{T, K}, x)
end


function convert{T}(::Type{Kmer}, seq::NucleotideSequence{T})
    return convert(Kmer{T}, seq)
end


function convert{T}(::Type{Kmer{T}}, seq::NucleotideSequence{T})
    k = length(seq)
    if k > 32
        error(string("Cannot construct a K-mer longer than 32nt."))
    end
    return convert(Kmer{T, k}, seq)
end


function convert{T, K}(::Type{Kmer{T, K}}, seq::NucleotideSequence{T})
    if length(seq) != K
        error(string("Cannot construct a $(K)-mer from a string of length $(length(seq))"))
    end

    x = uint64(0)
    shift = 0
    for (i, nt) in enumerate(seq)
        if nt == nnucleotide(T)
            error("A Kmer may not contain an N in its sequence")
        end
        x |= convert(Uint64, nt) << shift
        shift += 2
    end
    return convert(Kmer{T, K}, x)
end


function convert{T, K}(::Type{NucleotideSequence}, x::Kmer{T, K})
    return convert(NucleotideSequence{T}, x)
end


function convert{T, K}(::Type{NucleotideSequence{T}}, x::Kmer{T, K})
    ns = BitVector(K)
    fill!(ns, false)
    return NucleotideSequence{T}([convert(Uint64, x)], ns, 1:K)
end


function convert{T, K}(::Type{String}, seq::Kmer{T, K})
    return convert(String, [convert(Char, x) for x in seq])
end


function dnakmer(seq::String)
    return convert(DNAKmer, seq)
end


function rnakmer(seq::String)
    return convert(RNAKmer, seq)
end


# Constructors taking a sequence of nucleotides
function kmer{T <: Nucleotide}(nts::T...)
    K = length(nts)
    if K > 32
        error(string("Cannot construct a K-mer longer than 32nt."))
    end

    x = uint64(0)
    shift = 0
    for (i, nt) in enumerate(nts)
        if nt == nnucleotide(T)
            error("A Kmer may not contain an N in its sequence")
        end
        x |= convert(Uint64, nt) << shift

        shift += 2
    end
    return convert(Kmer{T, K}, x)
end


function dnakmer(seq::DNASequence)
    if length(seq) > 32
        error(string("Cannot construct a K-mer longer than 32nt."))
    end
    return convert(DNAKmer{length(seq)}, seq)
end


function dnakmer(seq::RNASequence)
    if length(seq) > 32
        error(string("Cannot construct a K-mer longer than 32nt."))
    end
    return convert(RNAKmer{length(seq)}, seq)
end


function rnakmer(seq::String)
    if length(seq) > 32
        error(string("Cannot construct a K-mer longer than 32nt."))
    end
    return convert(RNAKmer{length(seq)}, seq)
end


function getindex{T, K}(x::Kmer{T, K}, i::Integer)
    if i < 1 || i > K
        error(BoundsError())
    end
    convert(T, (convert(Uint64, x) >>> (2*(i-1))) & 0b11)
end


function show{K}(io::IO, x::DNAKmer{K})
    for i in 1:K
        write(io, convert(Char, x[i]))
    end
    print(io, "  (DNA $(K)-mer)")
end


function show{K}(io::IO, x::RNAKmer{K})
    for i in 1:K
        write(io, convert(Char, x[i]))
    end
    print(io, "  (RNA $(K)-mer)")
end


function isless{T, K}(x::Kmer{T, K}, y::Kmer{T, K})
    return convert(Uint64, x) < convert(Uint64, y)
end


function length{T, K}(x::Kmer{T, K})
    return K
end


# Iterate over nucleotides
function start(x::Kmer)
    return 1
end


function next{T, K}(x::Kmer{T, K}, i::Int)
    nt = convert(T, (convert(Uint64, x) >>> (2*(i-1))) & 0b11)
    return (nt, i + 1)
end


function done{T, K}(x::Kmer{T, K}, i::Int)
    return i > K
end


function reverse{T, K}(x::Kmer{T, K})
    return convert(Kmer{T, K}, nucrev(convert(Uint64, x)) >>> (2 * (32 - K)))
end


function complement{T, K}(x::Kmer{T, K})
    return convert(Kmer{T, K},
        (~convert(Uint64, x)) & (0xffffffffffffffff >>> (2 * (32 - K))))
end


function reverse_complement{T, K}(x::Kmer{T, K})
    return complement(reverse(x))
end


function mismatches{T, K}(x::Kmer{T, K}, y::Kmer{T, K})
    return nucmismatches(convert(Uint64, x), convert(Uint64, y))
end


# A canonical kmer is the numerical lesser of a k-mer and its reverse complement.
# This is useful in hashing/counting kmers in data that is not strand specific,
# and thus observing kmer is equivalent to observing its reverse complement.
function canonical{T, K}(x::Kmer{T, K})
    y = reverse_complement(x)
    return x < y ? x : y
end


# Iterate through every kmer in a nucleotide sequence
immutable EachKmerIterator{T, K}
    seq::NucleotideSequence{T}
    nit::SequenceNIterator
    step::Int
end


immutable EachKmerIteratorState{T, K}
    i::Int
    x::Uint64
    next_n_pos::Int
    nit_state::Int
end


function eachkmer{T}(seq::NucleotideSequence{T}, k::Integer, step::Integer=1)
    if k < 0
        error("K must be ≥ 0 in eachkmer")
    elseif k > 32
        error("K must be ≤ 32 in eachkmer")
    end

    if step < 1
        error("step must be ≥ 1")
    end

    return EachKmerIterator{T, k}(seq, npositions(seq), step)
end


function nextkmer{T, K}(it::EachKmerIterator{T, K},
                        state::EachKmerIteratorState{T, K}, skip::Int)
    i = state.i + 1
    x = state.x
    next_n_pos = state.next_n_pos
    nit_state = state.nit_state

    shift = 2 * (K - 1)
    d, r = divrem(2 * (it.seq.part.start + i - 2), 64)
    while i <= length(it.seq)
        while next_n_pos < i
            if done(it.nit, nit_state)
                next_n_pos = length(it.seq) + 1
                break
            else
                next_n_pos, nit_state = next(it.nit, nit_state)
            end
        end

        if i - K + 1 <= next_n_pos <= i
            off = it.step * iceil((K - skip) / it.step)
            if skip < K
                skip += off
            end
        end

        x = (x >>> 2) | (((it.seq.data[d + 1] >>> r) & 0b11) << shift)

        if skip == 0
            break
        end
        skip -= 1

        r += 2
        if r == 64
            r = 0
            d += 1
        end
        i += 1
    end

    return EachKmerIteratorState{T, K}(i, x, next_n_pos, nit_state)
end


function start{T, K}(it::EachKmerIterator{T, K})
    nit_state = start(it.nit)
    if done(it.nit, nit_state)
        next_n_pos = length(it.seq) + 1
    else
        next_n_pos, nit_state = next(it.nit, nit_state)
    end

    state = EachKmerIteratorState{T, K}(0, uint64(0), next_n_pos, nit_state)
    return nextkmer(it, state, K - 1)
end


function next{T, K}(it::EachKmerIterator{T, K},
                    state::EachKmerIteratorState{T, K})
    value = convert(Kmer{T, K}, state.x)
    next_state = nextkmer(it, state, it.step - 1)
    return (state.i - K + 1, value), next_state
end


function done{T, K}(it::EachKmerIterator{T, K},
                    state::EachKmerIteratorState{T, K})
    return state.i > length(it.seq)
end


function =={T, K}(a::NucleotideSequence{T}, b::Kmer{T, K})
    if length(a) != K
        return false
    end

    for (u, v) in zip(a, b)
        if u != v
            return false
        end
    end

    return true
end


function =={T, K}(a::Kmer{T, K}, b::NucleotideSequence{T})
    return b == a
end

# TODO: count_nucleotides


