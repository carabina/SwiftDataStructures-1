# SwiftDataStructures

SwiftDataStructures is a framework of commonly-used data structures for Swift. Documentation is available [here](http://oisdk.github.io/SwiftDataStructures/index.html).

Included:

## Deque ##

A [Deque](https://en.wikipedia.org/wiki/Double-ended_queue) is a data structure comprised
of two queues, with the first queue beginning at the start of the Deque, and the second
beginning at the end (in reverse):

```swift
First queue   Second queue
v              v
[0, 1, 2, 3] | [3, 2, 1, 0]
```

This allows for O(*1*) prepending, appending, and removal of first and last elements.

This implementation of a Deque uses two reversed `ContiguousArray`s as the queues. (this
means that the first array has reversed semantics, while the second does not) This allows
for O(*1*) indexing.

Discussion of this specific implementation is available
[here](https://bigonotetaking.wordpress.com/2015/08/09/yet-another-root-of-all-evil/).

## Stack ##

A `Stack` is a list-like data structure, implemented via a reversed
`ContiguousArray`. It has performance characteristics similar to an array, except that
operations on the *beginning* generally have complexity of amortized O(1), whereas
operations on the *end* are usually O(`count`).

Discussion of this specific implementation is available
[here](https://bigonotetaking.wordpress.com/2015/08/09/yet-another-root-of-all-evil/).

## List ##

A singly-linked, recursive list. Head-tail decomposition can be accomplished with a
`switch` statement:

```swift
extension List {
  public func map<T>(f: Element -> T) -> List<T> {
    switch self {
    case .Nil: return .Nil
    case let .Cons(x, xs): return f(x) |> xs().map(f)
    }
  }
}
```

Where `|>` is the [cons](https://en.wikipedia.org/wiki/Cons) operator.

Operations on the beginning of the list are O(1), whereas other operations are O(n).

Discussion of this specific implementation is available
[here](https://bigonotetaking.wordpress.com/2015/07/29/deques-queues-and-lists-in-swift-with-indirect/).

## Trie ##

A [Trie](https://en.wikipedia.org/wiki/Trie) is a prefix tree data structure. It has
set-like operations and properties. Instead of storing hashable elements, however, it
stores *sequences* of hashable elements. As well as set operations, the Trie can be
searched by prefix. Insertion, deletion, and searching are all O(`n`), where `n` is the
length of the sequence being searched for.

![Trie](https://upload.wikimedia.org/wikipedia/commons/b/be/Trie_example.svg "Trie")

Discussion of this specific implementation is available
[here](https://bigonotetaking.wordpress.com/2015/08/11/a-trie-in-swift/).