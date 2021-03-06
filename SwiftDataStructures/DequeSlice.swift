/**
A [Deque](https://en.wikipedia.org/wiki/Double-ended_queue) is a data structure comprised
of two queues, with the first queue beginning at the start of the Deque, and the second
beginning at the end (in reverse):

```
First queue   Second queue
v              v
[0, 1, 2, 3] | [3, 2, 1, 0]
```

This allows for O(*1*) prepending, appending, and removal of first and last elements.

This implementation of a Deque uses two reversed `ArraySlice`s as the queues. (this
means that the first array has reversed semantics, while the second does not) This allows
for O(*1*) indexing.

Because an `ArraySlice` presents a view onto the storage of some larger array even after
the original array's lifetime ends, storing the slice may prolong the lifetime of elements
that are no longer accessible, which can manifest as apparent memory and object leakage.
To prevent this effect, use `DequeSlice` only for transient computation.

Discussion of this specific implementation is available
[here](https://bigonotetaking.wordpress.com/2015/08/09/yet-another-root-of-all-evil/).
*/

public struct DequeSlice<Element> : CustomDebugStringConvertible, ArrayLiteralConvertible, SequenceType, Indexable, MutableSliceable, RangeReplaceableCollectionType {
  internal var front, back: ArraySlice<Element>

  public typealias SubSequence = DequeSlice<Element>
  public typealias Generator = DequeSliceGenerator<Element>

  // MARK: Initilalizers
  
  /// Constructs an empty `Deque`
  public init() {
    (front, back) = ([], [])
  }
  
  internal init(_ front: ArraySlice<Element>, _ back: ArraySlice<Element>) {
    (self.front, self.back) = (front, back)
    check()
  }
  
  internal init(balancedF: ArraySlice<Element>, balancedB: ArraySlice<Element>) {
    (front, back) = (balancedF, balancedB)
  }
  
  /// Initilalize from a `Deque`
  
  public init(_ from: Deque<Element>) {
    (front, back) = (ArraySlice(from.front), ArraySlice(from.back))
  }
  
  internal init(array: [Element]) {
    let half = array.endIndex / 2
    self.init(
      balancedF: ArraySlice(array[0..<half].reverse()),
      balancedB: ArraySlice(array[half..<array.endIndex])
    )
  }
  
  /// Construct from an arbitrary sequence with elements of type `Element`.
  public init<S : SequenceType where S.Generator.Element == Element>(_ seq: S) {
    self.init(array: Array(seq))
  }
  /// Create an instance containing `elements`.
  public init(arrayLiteral elements: Element...) {
    self.init(array: elements)
  }
  
  // MARK: Instance Properties
  
  /// A textual representation of `self`, suitable for debugging.
  public var debugDescription: String {
    return
      "[" +
        ", ".join(front.reverse().map { String(reflecting: $0) }) +
        " | " +
        ", ".join(back.map { String(reflecting: $0) }) + "]"
  }

  internal var balance: Balance {
    let (f, b) = (front.count, back.count)
    if f == 0 {
      if b > 1 {
        return .FrontEmpty
      }
    } else if b == 0 {
      if f > 1 {
        return .BackEmpty
      }
    }
    return .Balanced
  }
  
  /**
  The position of the first element in a non-empty `DequeSlice`.
  
  In an empty `DequeSlice`, `startIndex == endIndex`.
  */
  public var startIndex: Int { return 0 }
  /**
  The `DequeSlice`'s "past the end" position.
  
  `endIndex` is not a valid argument to `subscript`, and is always reachable from
  `startIndex` by zero or more applications of `successor()`.
  */
  public var endIndex: Int { return front.endIndex + back.endIndex }
  
  /**
  Returns the number of elements.
  
  - Complexity: O(1)
  */
  public var count: Int {
    return endIndex
  }
  /**
  Returns the first element of `self`, or `nil` if `self` is empty.
  */
  public var first: Element? {
    return front.last ?? back.first
  }
  /**
  Returns the last element of `self`, or `nil` if `self` is empty.
  */
  public var last: Element? {
    return back.last ?? front.first
  }
  /**
  Returns `true` iff `self` is empty.
  */
  public var isEmpty: Bool {
    return front.isEmpty && back.isEmpty
  }
  
  // MARK: Instance Methods
  
  /**
  This is the function that maintains an invariant: If either queue has more than one
  element, the other must not be empty. This ensures that all operations can be performed
  efficiently. It is caried out whenever a mutating funciton which may break the invariant
  is performed.
  */
  
  internal mutating func check() {
    switch balance {
    case .FrontEmpty:
      front.reserveCapacity(back.count - 1)
      let newBack = back.removeLast()
      front = ArraySlice(back.reverse())
      back = [newBack]
    case .BackEmpty:
      back.reserveCapacity(front.count - 1)
      let newFront = front.removeLast()
      back = ArraySlice(front.reverse())
      front = [newFront]
    case .Balanced: return
    }
  }

  /**
  Return a `DequeSliceGenerator` over the elements of this
  `DequeSlice`.
  
  - Complexity: O(1)
  */
  public func generate() -> DequeSliceGenerator<Element> {
    return DequeSliceGenerator(fGen: front.reverse().generate(), sGen: back.generate())
  }
  /**
  Return a value less than or equal to the number of elements in `self`,
  **nondestructively**.
  */
  public func underestimateCount() -> Int {
    return front.underestimateCount() + back.underestimateCount()
  }
  /**
  Returns a `DequeSlice` containing all but the first element.
  
  - Complexity: O(1)
  */
  public func dropFirst() -> DequeSlice<Element> {
    if front.isEmpty { return DequeSlice() }
    return DequeSlice(front.dropLast(), ArraySlice(back))
  }
  /**
  Returns a `DequeSlice` containing all but the first n elements.
  
  - Requires: `n >= 0`
  - Complexity: O(1)
  */
  public func dropFirst(n: Int) -> DequeSlice<Element> {
    if n < front.endIndex {
      return DequeSlice(
        balancedF: front.dropLast(n),
        balancedB: ArraySlice(back)
      )
    } else {
      let i = n - front.endIndex
      if i >= back.endIndex { return [] }
      return DequeSlice(
        balancedF: [back[i]],
        balancedB: back.dropFirst(i.successor())
      )
    }
  }
  /**
  Returns a `DequeSlice` containing all but the last element.
  
  - Complexity: O(1)
  */
  public func dropLast() -> DequeSlice<Element> {
    if back.isEmpty { return DequeSlice() }
    return DequeSlice(ArraySlice(front), back.dropLast())
  }
  /**
  Returns a `DequeSlice` containing all but the last n elements.
  
  - Requires: `n >= 0`
  - Complexity: O(1)
  */
  public func dropLast(n: Int) -> DequeSlice<Element> {
    if n < back.endIndex {
      return DequeSlice(
        balancedF: ArraySlice(front),
        balancedB: back.dropLast(n)
      )
    } else {
      let i = n - back.endIndex
      if i >= front.endIndex { return [] }
      return DequeSlice(
        balancedF: front.dropFirst(i.successor()),
        balancedB: [front[i]]
      )
    }
  }
  /**
  Returns a `DequeSlice`, up to `maxLength` in length, containing the initial
  elements of `self`.
  
  If maxLength exceeds self.count, the result contains all the elements of self.
  
  - Requires: `maxLength >= 0`
  - Complexity: O(1)
  */
  public func prefix(maxLength: Int) -> DequeSlice<Element> {
    if maxLength == 0 { return [] }
    if maxLength <= front.endIndex {
      let i = front.endIndex - maxLength
      return DequeSlice(
        balancedF: front.suffix(maxLength.predecessor()),
        balancedB: [front[i]]
      )
    } else {
      let i = maxLength - front.endIndex
      return DequeSlice(
        balancedF: ArraySlice(front),
        balancedB: back.prefix(i)
      )
    }
  }
  /**
  Returns a `DequeSlice`, up to `maxLength` in length, containing the final
  elements of `self`.
  
  If `maxLength` exceeds `self.count`, the result contains all the elements of `self`.
  
  - Requires: maxLength >= 0
  - Complexity: O(1)
  */
  public func suffix(maxLength: Int) -> DequeSlice<Element> {
    if maxLength == 0 { return [] }
    if maxLength <= back.endIndex {
      return DequeSlice(
        balancedF: [back[back.endIndex - maxLength]],
        balancedB: back.suffix(maxLength.predecessor())
      )
    } else {
      return DequeSlice(
        balancedF: front.prefix(maxLength - back.endIndex),
        balancedB: ArraySlice(back)
      )
    }
  }
  /**
  Returns the maximal `DequeSlice`s of `self`, in order, that don't contain
  elements satisfying the predicate `isSeparator`.
  
  - Parameter maxSplits: The maximum number of `DequeSlice`s to return, minus 1.
  If `maxSplit` + 1 `DequeSlice`s are returned, the last one is a suffix of
  `self` containing the remaining elements. The default value is `Int.max`.
  - Parameter allowEmptySubsequences: If `true`, an empty `DequeSlice` is
  produced in the result for each pair of consecutive elements satisfying `isSeparator`.
  The default value is false.
  - Requires: maxSplit >= 0
  */
  public func split(
    maxSplit: Int,
    allowEmptySlices: Bool,
    @noescape isSeparator: Element -> Bool
    ) -> [DequeSlice<Element>] {
      var result: [DequeSlice<Element>] = []
      var i = startIndex
      for j in indices where isSeparator(self[i]) {
        let slice = self[i..<j]
        i = j.successor()
        if (!slice.isEmpty || allowEmptySlices) {
          result.append(slice)
        }
        if result.count > maxSplit {
          result.append(self[i..<endIndex])
          return result
        }
      }
      return result
  }

  /**
  Access the `element` at `position`.
  
  - Requires: `position` is a valid `position` in `self` and `position != endIndex`.
  */
  public subscript(idx: Int) -> Element {
    get {
      return idx < front.endIndex ?
        front[front.endIndex.predecessor() - idx] :
        back[idx - front.endIndex]
    } set {
      idx < front.endIndex ?
        (front[front.endIndex.predecessor() - idx] = newValue) :
        (back[idx - front.endIndex] = newValue)
    }
  }


  /**
  If `!self.isEmpty`, remove the first element and return it, otherwise return `nil`.
  
  - Complexity: Amortized O(1)
  */
  public mutating func popFirst() -> Element? {
    defer { check() }
    return front.popLast() ?? back.popLast()
  }
  /**
  If `!self.isEmpty`, remove the last element and return it, otherwise return `nil`.
  
  - Complexity: Amortized O(1)
  */
  public mutating func popLast() -> Element? {
    defer { check() }
    return back.popLast() ?? front.popLast()
  }
  /**
  Returns `self[startIndex..<end]`
  
  - Complexity: O(1)
  */
  public func prefixUpTo(end: Int) -> DequeSlice<Element> {
    return prefix(end)
  }
  /**
  Returns `prefixUpTo(position.successor())`
  
  - Complexity: O(1)
  */
  public func prefixThrough(position: Int) -> DequeSlice<Element> {
    return prefix(position.successor())
  }
  /**
  Return a `Deque` containing the elements of `self` in reverse order.
  
  - Complexity: O(1)
  */
  public func reverse() -> DequeSlice<Element> {
    return DequeSlice(balancedF: back, balancedB: front)
  }
  /**
  Returns `self[start..<endIndex]`
  
  - Complexity: O(1)
  */
  public func suffixFrom(start: Int) -> DequeSlice<Element> {
    return dropFirst(start)
  }
  
  /**
  Accesses the elements at the given subRange
  
  - Complexity: O(1)
  */
  public subscript(idxs: Range<Int>) -> DequeSlice<Element> {
    get {
      if idxs.startIndex == idxs.endIndex { return [] }
      switch (idxs.startIndex < front.endIndex, idxs.endIndex <= front.endIndex) {
      case (true, true):
        let start = front.endIndex - idxs.endIndex
        let end   = front.endIndex - idxs.startIndex
        return DequeSlice(
          balancedF: front[start.successor()..<end],
          balancedB: [front[start]]
        )
      case (true, false):
        let frontTo = front.endIndex - idxs.startIndex
        let backTo  = idxs.endIndex - front.endIndex
        return DequeSlice(
          balancedF: front[front.startIndex ..< frontTo],
          balancedB: back [back.startIndex ..< backTo]
        )
      case (false, false):
        let start = idxs.startIndex - front.endIndex
        let end   = idxs.endIndex - front.endIndex
        return DequeSlice(
          balancedF: [back[start]],
          balancedB: back[start.successor() ..< end]
        )
      case (false, true): return []
      }
    } set {
      for (index, value) in zip(idxs, newValue) {
        self[index] = value
      }
    }
  }

  /**
  Append `x` to `self`.
  
  Applying `successor()` to the index of the new element yields `self.endIndex`.
  
  - Complexity: Amortized O(1).
  */
  public mutating func append(with: Element) {
    back.append(with)
    check()
  }
  /**
  Append the elements of `newElements` to `self`.
  
  - Complexity: O(*length of result*).
  */
  public mutating func extend<S : SequenceType where S.Generator.Element == Element>(with: S) {
    back.extend(with)
    check()
  }
  /**
  Insert `newElement` at index `i`.
  
  - Requires: `i <= count`.
  - Complexity: O(`count`).
  */
  public mutating func insert(newElement: Element, atIndex i: Int) {
    i < front.endIndex ?
      front.insert(newElement, atIndex: front.endIndex - i) :
      back .insert(newElement, atIndex: i - front.endIndex)
    check()
  }
  /**
  Prepend `x` to `self`.
  
  The index of the new element is `self.startIndex`.
  
  - Complexity: Amortized O(1).
  */
  public mutating func prepend(with: Element) {
    front.append(with)
    check()
  }
  /**
  Prepend the elements of `newElements` to `self`.
  
  - Complexity: O(*length of result*).
  */
  public mutating func prextend<S : SequenceType where S.Generator.Element == Element>(with: S) {
    front.extend(with.reverse())
    check()
  }
  /**
  Remove all elements.
  
  - Postcondition: `capacity == 0` iff `keepCapacity` is `false`.
  - Complexity: O(`self.count`).
  */
  public mutating func removeAll(keepCapacity: Bool = false) {
    front.removeAll(keepCapacity: keepCapacity)
    back .removeAll(keepCapacity: keepCapacity)
  }
  /**
  Remove and return the element at index `i`.
  
  Invalidates all indices with respect to `self`.
  
  - Complexity: O(`count`).
  */
  public mutating func removeAtIndex(i: Int) -> Element {
    defer { check() }
    return i < front.endIndex ?
      front.removeAtIndex(front.endIndex.predecessor() - i) :
      back .removeAtIndex(i - front.endIndex)
  }
  /**
  Remove the element at `startIndex` and return it.
  
  - Complexity: Amortized O(1)
  - Requires: `!self.isEmpty`.
  */
  public mutating func removeFirst() -> Element {
    if front.isEmpty { return back.removeLast() }
    defer { check() }
    return front.removeLast()
  }
  /**
  Remove the first `n` elements.
  
  - Complexity: O(`self.count`)
  - Requires: `!self.isEmpty`.
  */
  public mutating func removeFirst(n: Int) {
    if n < front.endIndex {
      front.removeRange((front.endIndex - n)..<front.endIndex)
    } else {
      let i = n - front.endIndex
      if i < back.endIndex {
        self = DequeSlice(
          balancedF: [back[i]],
          balancedB: ArraySlice(back.dropFirst(i.successor()))
        )
      } else {
        removeAll()
      }
    }
  }
  /**
  Remove an element from the end.
  
  - Complexity: Amortized O(1)
  - Requires: `!self.isEmpty`
  */
  public mutating func removeLast() -> Element {
    if back.isEmpty { return front.removeLast() }
    defer { check() }
    return back.removeLast()
  }
  /**
  Remove the last `n` elements.
  
  - Complexity: O(`self.count`)
  - Requires: `!self.isEmpty`.
  */
  public mutating func removeLast(n: Int) {
    if n < back.endIndex {
      back.removeRange((back.endIndex - n)..<back.endIndex)
    } else {
      let i = n - back.endIndex
      if i < front.endIndex {
        self = DequeSlice(
          balancedF: ArraySlice(front.dropFirst(i.successor())),
          balancedB: [front[i]]
        )
      } else {
        removeAll()
      }
    }
  }
  /**
  Remove the indicated subRange of elements.
  
  Invalidates all indices with respect to `self`.
  
  - Complexity: O(`self.count`).
  */
  public mutating func removeRange(subRange: Range<Int>) {
    if subRange.startIndex == subRange.endIndex { return }
    defer { check() }
    switch (subRange.startIndex < front.endIndex, subRange.endIndex <= front.endIndex) {
    case (true, true):
      let start = front.endIndex - subRange.endIndex
      let end   = front.endIndex - subRange.startIndex
      front.removeRange(start..<end)
    case (true, false):
      let frontTo = front.endIndex - subRange.startIndex
      let backTo  = subRange.endIndex - front.endIndex
      front.removeRange(front.startIndex..<frontTo)
      back.removeRange(back.startIndex..<backTo)
    case (false, false):
      let start = subRange.startIndex - front.endIndex
      let end   = subRange.endIndex - front.endIndex
      back.removeRange(start..<end)
    case (false, true): return
    }
  }
  /**
  Replace the given `subRange` of elements with `newElements`.
  
  Invalidates all indices with respect to `self`.
  
  - Complexity: O(`subRange.count`) if `subRange.endIndex == self.endIndex` and
  `isEmpty(newElements)`, O(`self.count + newElements.count`) otherwise.
  */
  public mutating func replaceRange<
    C : CollectionType where C.Generator.Element == Element
    >(subRange: Range<Int>, with newElements: C) {
      defer { check() }
      switch (subRange.startIndex < front.endIndex, subRange.endIndex <= front.endIndex) {
      case (true, true):
        let start = front.endIndex - subRange.endIndex
        let end   = front.endIndex - subRange.startIndex
        front.replaceRange(start..<end, with: newElements.reverse())
      case (true, false):
        let frontTo = front.endIndex - subRange.startIndex
        let backTo  = subRange.endIndex - front.endIndex
        front.removeRange(front.startIndex..<frontTo)
        back.replaceRange(back.startIndex..<backTo, with: newElements)
      case (false, false):
        let start = subRange.startIndex - front.endIndex
        let end   = subRange.endIndex - front.endIndex
        back.replaceRange(start..<end, with: newElements)
      case (false, true):
        back.replaceRange(back.startIndex..<back.startIndex, with: newElements)
      }
  }
  /**
  Reserve enough space to store `minimumCapacity` elements.
  
  - Postcondition: `capacity >= minimumCapacity` and the `DequeSlice` has
  mutable contiguous storage.
  - Complexity: O(`count`).
  */
  mutating public func reserveCapacity(n: Int) {
    let half = n / 2
    front.reserveCapacity(half)
    back.reserveCapacity(n - half)
  }
}
/// :nodoc:
public struct DequeSliceGenerator<Element> : GeneratorType, SequenceType {
  private var fGen: IndexingGenerator<ReverseRandomAccessCollection<ArraySlice<Element>>>?
  private var sGen: IndexingGenerator<ArraySlice<Element>>
  
  /**
  Advance to the next element and return it, or `nil` if no next element exists.
  
  - Requires: `next()` has not been applied to a copy of `self` since the copy was made,
  and no preceding call to `self.next()` has returned `nil`.
  */
  
  mutating public func next() -> Element? {
    if fGen == nil { return sGen.next() }
    return fGen!.next() ?? {
      fGen = nil
      return sGen.next()
      }()
  }
}