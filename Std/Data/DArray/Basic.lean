/-
Copyright (c) 2023 Mario Carneiro. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Mario Carneiro
-/
import Std.Data.Array.Init.Basic
import Std.Data.Nat.Lemmas
import Std.Data.Fin.Lemmas

/-!
## Dependent arrays

This file contains some definitions in `Array` needed for `Std.List.Basic`.
-/

namespace Std

/--
`DArray sz α` is the type of (dependently typed)
[dynamic arrays](https://en.wikipedia.org/wiki/Dynamic_array) with size `sz`,
where the element of index `i` has type `α i`. This type has special support in the runtime.

An array has a size and a capacity; the size is `sz` but the capacity
is not observable from lean code. Arrays perform best when unshared; as long
as they are used "linearly" all updates will be performed destructively on the
array, so it has comparable performance to mutable arrays in imperative
programming languages.
-/
structure DArray (sz : Nat) (α : Fin sz → Type u) : Type u where
  /-- Create a new array of size `sz` from a dependent function of type `∀ i : Fin sz, α i`. -/
  ofFn ::
  /-- A dependently typed version of `Array.get`, which returns the `i`'th element of the array. -/
  get (i : Fin sz) : α i

/--
An abbreviation for `DArray` in the special case where `α` is defined for all `i : Nat`, not
just `i : Fin sz`.
-/
abbrev DNArray (sz : Nat) (α : Nat → Type u) := DArray sz (α ·)

/--
An abbreviation for `DArray` in the special case where `α` is actually a constant. This is similar
to (and interconvertible with) `Array α`, except that `sz` is part of the type.
-/
abbrev CArray (sz : Nat) (α : Type u) := DNArray sz fun _ => α

namespace DArray

@[inline] private unsafe def ofFnImpl (f : (i : Fin sz) → α i) : DArray sz α :=
  unsafeCast <| Array.ofFn fun i => (unsafeCast (f i) : NonScalar)
attribute [implemented_by ofFnImpl] ofFn

@[inline] private unsafe def getImpl (self : DArray sz α) (i : Fin sz) : α i :=
  unsafeCast <| Array.get (α := NonScalar) (unsafeCast self) (unsafeCast i)
attribute [implemented_by getImpl] get

@[inline] private def casesOnImpl {motive : DArray sz α → Sort v}
    (t : DArray sz α) (F : ∀ get, motive { get }) : motive t := F _
attribute [implemented_by DArray.casesOn] casesOnImpl

@[inline] private unsafe def mkEmptyImpl (c : Nat) : DArray 0 α :=
  unsafeCast <| Array.mkEmpty (α := NonScalar) c
/-- Construct a new empty array with initial capacity `c`. -/

@[implemented_by mkEmptyImpl, nolint unusedArguments]
def mkEmpty (c : Nat) : DArray 0 α := ⟨fun.⟩

/-- Construct a new empty array. -/
@[inline] def empty : DArray 0 α := mkEmpty 0

/--
Get the size of an array. This is provided for convenience, it should usually not be needed
since the size of a `DArray` is one of the parameters of the type.
-/
@[nolint unusedArguments] abbrev size (_self : DArray sz α) : Nat := sz

/-- Access an element from an array, or return `v₀` if the index is out of bounds. -/
@[inline] abbrev getD (a : DNArray sz α) (i : Nat) (v₀ : α i) : α i :=
  if h : i < sz then a.get ⟨i, h⟩ else v₀

/-- Access an element from an array, or panic if the index is out of bounds. -/
@[inline] def get! {α : Nat → Type u}
    (a : DNArray sz α) (i : Nat) [Inhabited (α i)] : α i := getD a i default

@[inline] private unsafe def pushImpl
    (a : DArray sz (α ∘ .castSucc)) (v : α (.last sz)) : DArray (sz+1) α :=
  unsafeCast <| Array.push (α := NonScalar) (unsafeCast a) (unsafeCast v)

/--
Push an element onto the end of an array. This is amortized O(1) because
`DArray sz α` is internally a dynamic array.
-/
@[implemented_by pushImpl] def push
    (a : DArray sz (α ∘ .castSucc)) (v : α (.last sz)) : DArray (sz+1) α where
  get i :=
    if h : i < sz then a.get ⟨i, h⟩
    else
      (Fin.eq_of_val_eq <| Nat.le_antisymm (Nat.not_lt.1 h) (Nat.le_of_lt_succ i.2)
        : Fin.last sz = i) ▸ v

@[inline] private unsafe def setImpl (a : DArray sz α) (i : Fin sz) (v : α i) : DArray sz α :=
  unsafeCast <| Array.set (α := NonScalar) (unsafeCast a) (unsafeCast i) (unsafeCast v)

/--
Set an element in an array without bounds checks, using a `Fin` index.

This will perform the update destructively provided that `a` has a reference
count of 1 when called.
-/
@[implemented_by setImpl] def set (a : DArray sz α) (i : Fin sz) (v : α i) : DArray sz α where
  get j := if h : i = j then h ▸ v else a.get j

/--
Set an element in an array, or do nothing if the index is out of bounds.

This will perform the update destructively provided that `a` has a reference
count of 1 when called.
-/
@[inline] def setD (a : DNArray sz α) (i : Nat) (v : α i) : DNArray sz α :=
  if h : i < sz then a.set ⟨i, h⟩ v else a

@[inline] private unsafe def set!Impl (a : DNArray sz α) (i : Nat) (v : α i) : DNArray sz α :=
  unsafeCast <| Array.set! (α := NonScalar) (unsafeCast a) i (unsafeCast v)

/--
Set an element in an array, or panic if the index is out of bounds.

This will perform the update destructively provided that `a` has a reference
count of 1 when called.
-/
@[implemented_by set!Impl] def set! (a : DNArray sz α) (i : Nat) (v : α i) : DNArray sz α :=
  setD a i v

@[inline] private unsafe def extractImpl
    (as : DArray sz α) (start sz' : Nat) (h : start + sz' ≤ sz) :
    DArray sz' fun i => α (Fin.castLE h (Fin.natAdd start i)) :=
  unsafeCast <| Array.extract.loop (α := NonScalar) (unsafeCast as) sz' start (.mkEmpty sz')

/-- `O(sz')`. Returns the slice of `as` from indices `start` to `start + sz'` (exclusive). -/
@[implemented_by extractImpl]
def extract (as : DArray sz α) (start sz' : Nat) (h : start + sz' ≤ sz) :
    DArray sz' fun i => α (Fin.castLE h (Fin.natAdd start i)) where
  get j := as.get ⟨start + j, Nat.lt_of_lt_of_le (Nat.add_lt_add_left j.2 _) h⟩

/--
`O(1)`. Is this array empty? Provided as a convenience, you don't need the `DArray` since the
size is known from the type.
-/
@[nolint unusedArguments] abbrev isEmpty (_ : DArray sz α) : Bool := sz = 0

/-- `O(1)`. Zero cost convert a dependent array to a regular array. -/
def ofArray (as : Array α) (h : as.size = sz := by rfl) : CArray sz α where
  get i := as.get (h ▸ i)

-- HACK, we can't restate the type because `:= by rfl` creates a new term each time it is written
@[inline] private unsafe def ofArrayImpl : type_of% @ofArray := fun as _ => unsafeCast as
attribute [implemented_by ofArrayImpl] ofArray

@[inline] private unsafe def toArrayImpl (as : CArray sz α) : Array α := unsafeCast as

/-- `O(1)`. Zero cost convert a regular array to a dependent array. -/
@[implemented_by toArrayImpl]
def toArray (as : CArray sz α) : Array α := Array.ofFn as.get

/--
`O(n)`. Create a new array by copying value `v` into every slot.
(This is a special case of `ofFn`, but implemented in a more efficient way.)
-/
def replicate (sz : Nat) (v : α) : CArray sz α :=
  ofArray (.mkArray sz v) (Array.size_mkArray ..)

/-- `O(1)`. Constructs an array with one element. -/
def singleton (v : α 0) : DArray 1 α := (mkEmpty 1).push v

@[inline] private unsafe def ugetImpl
    (a : DArray sz α) (i : USize) (h : i.toNat < sz) : α ⟨i.toNat, h⟩ :=
  unsafeCast <| Array.uget (α := NonScalar) (unsafeCast a) i lcProof

/-- Low-level version of `get` which is as fast as a C array read.
   `Fin` values are represented as tagged pointers in the Lean runtime. Thus,
   `fget` may be slightly slower than `uget`. -/
@[implemented_by ugetImpl]
def uget (a : DArray sz α) (i : USize) (h : i.toNat < sz) : α ⟨i.toNat, h⟩ :=
  a.get ⟨i.toNat, h⟩

/-- `O(1)`. Returns the last element of a nonempty array. -/
@[inline] def back (a : DArray (sz+1) α) : α (.last sz) := a.get ⟨sz, Nat.lt_succ_self _⟩

/-- `O(1)`. Gets an element from the array, or `none` if the index is out of range. -/
def get? (a : DNArray sz α) (i : Nat) : Option (α i) :=
  if h : i < sz then some (a.get ⟨i, h⟩) else none

/-- `O(1)`. Returns the last element of the array, or `none` if the array is empty. -/
def back? (a : DNArray sz α) : Option (α (sz - 1)) :=
  match sz with
  | 0 => none
  | _ + 1 => some a.back

@[inline] private unsafe def usetImpl
    (a : DArray sz α) (i : USize) (h : i.toNat < sz) (v : α ⟨i.toNat, h⟩) : DArray sz α :=
  unsafeCast <| Array.uset (α := NonScalar) (unsafeCast a) i (unsafeCast v) lcProof

/-- Low-level version of `set` which is as fast as a C array set.
   `Fin` values are represented as tagged pointers in the Lean runtime. Thus,
   `set` may be slightly slower than `uset`. -/
@[implemented_by usetImpl]
def uset (a : DArray sz α) (i : USize) (h : i.toNat < sz) (v : α ⟨i.toNat, h⟩) : DArray sz α :=
  a.set ⟨i.toNat, h⟩ v

/--
`O(1)`. Replaces the element at index `i` by `v`, and returns it. This uses all values linearly.
-/
@[inline] def swapAt (a : DArray sz α) (i : Fin sz) (v : α i) : α i × DArray sz α :=
  let e := a.get i
  let a := a.set i v
  (e, a)

/-- Amortized `O(1)`. Returns the last element of the array. -/
def pop (a : DArray (sz+1) α) : DArray sz (α ∘ .castSucc) where
  get i := a.get ⟨i, Nat.lt_succ_of_lt i.2⟩

/-- `O(sz - n)`. Pops elements from `a` until it has size `n`. -/
def shrink (a : DArray sz α) (n : Nat) (h : n ≤ sz) : DArray n (α ∘ .castLE h) :=
  if eq : n = sz then
    cast (by subst eq; rfl) a
  else
    match sz with
    | 0 => (eq <| Nat.le_zero.1 h).elim
    | _ + 1 => shrink a.pop n <| Nat.le_of_lt_succ <| Nat.lt_of_le_of_ne h eq

-- TODO
/-
@[inline]
unsafe def modifyMUnsafe [Monad m] (a : Array α) (i : Nat) (f : α → m α) : m (Array α) := do
  if h : i < a.size then
    let idx : Fin a.size := ⟨i, h⟩
    let v                := a.get idx
    -- Replace a[i] by `box(0)`.  This ensures that `v` remains unshared if possible.
    -- Note: we assume that arrays have a uniform representation irrespective
    -- of the element type, and that it is valid to store `box(0)` in any array.
    let a'               := a.set idx (unsafeCast ())
    let v ← f v
    pure <| a'.set (size_set a .. ▸ idx) v
  else
    pure a

@[implemented_by modifyMUnsafe]
def modifyM [Monad m] (a : Array α) (i : Nat) (f : α → m α) : m (Array α) := do
  if h : i < a.size then
    let idx := ⟨i, h⟩
    let v   := a.get idx
    let v ← f v
    pure <| a.set idx v
  else
    pure a

@[inline]
def modify (a : Array α) (i : Nat) (f : α → α) : Array α :=
  Id.run <| modifyM a i f

@[inline]
def modifyOp (self : Array α) (idx : Nat) (f : α → α) : Array α :=
  self.modify idx f

/--
  We claim this unsafe implementation is correct because an array cannot have more than `usizeSz` elements in our runtime.

  This kind of low level trick can be removed with a little bit of compiler support. For example, if the compiler simplifies `as.size < usizeSz` to true. -/
@[inline] unsafe def forInUnsafe {α : Type u} {β : Type v} {m : Type v → Type w} [Monad m] (as : Array α) (b : β) (f : α → β → m (ForInStep β)) : m β :=
  let sz := USize.ofNat as.size
  let rec @[specialize] loop (i : USize) (b : β) : m β := do
    if i < sz then
      let a := as.uget i lcProof
      match (← f a b) with
      | ForInStep.done  b => pure b
      | ForInStep.yield b => loop (i+1) b
    else
      pure b
  loop 0 b

/-- Reference implementation for `forIn` -/
@[implemented_by Array.forInUnsafe]
protected def forIn {α : Type u} {β : Type v} {m : Type v → Type w} [Monad m] (as : Array α) (b : β) (f : α → β → m (ForInStep β)) : m β :=
  let rec loop (i : Nat) (h : i ≤ as.size) (b : β) : m β := do
    match i, h with
    | 0,   _ => pure b
    | i+1, h =>
      have h' : i < as.size            := Nat.lt_of_lt_of_le (Nat.lt_succ_self i) h
      have : as.size - 1 < as.size     := Nat.sub_lt (Nat.zero_lt_of_lt h') (by decide)
      have : as.size - 1 - i < as.size := Nat.lt_of_le_of_lt (Nat.sub_le (as.size - 1) i) this
      match (← f as[as.size - 1 - i] b) with
      | ForInStep.done b  => pure b
      | ForInStep.yield b => loop i (Nat.le_of_lt h') b
  loop as.size (Nat.le_refl _) b

instance : ForIn m (Array α) α where
  forIn := Array.forIn

/-- See comment at `forInUnsafe` -/
@[inline]
unsafe def foldlMUnsafe {α : Type u} {β : Type v} {m : Type v → Type w} [Monad m] (f : β → α → m β) (init : β) (as : Array α) (start := 0) (stop := as.size) : m β :=
  let rec @[specialize] fold (i : USize) (stop : USize) (b : β) : m β := do
    if i == stop then
      pure b
    else
      fold (i+1) stop (← f b (as.uget i lcProof))
  if start < stop then
    if stop ≤ as.size then
      fold (USize.ofNat start) (USize.ofNat stop) init
    else
      pure init
  else
    pure init

/-- Reference implementation for `foldlM` -/
@[implemented_by foldlMUnsafe]
def foldlM {α : Type u} {β : Type v} {m : Type v → Type w} [Monad m] (f : β → α → m β) (init : β) (as : Array α) (start := 0) (stop := as.size) : m β :=
  let fold (stop : Nat) (h : stop ≤ as.size) :=
    let rec loop (i : Nat) (j : Nat) (b : β) : m β := do
      if hlt : j < stop then
        match i with
        | 0    => pure b
        | i'+1 =>
          have : j < as.size := Nat.lt_of_lt_of_le hlt h
          loop i' (j+1) (← f b as[j])
      else
        pure b
    loop (stop - start) start init
  if h : stop ≤ as.size then
    fold stop h
  else
    fold as.size (Nat.le_refl _)

/-- See comment at `forInUnsafe` -/
@[inline]
unsafe def foldrMUnsafe {α : Type u} {β : Type v} {m : Type v → Type w} [Monad m] (f : α → β → m β) (init : β) (as : Array α) (start := as.size) (stop := 0) : m β :=
  let rec @[specialize] fold (i : USize) (stop : USize) (b : β) : m β := do
    if i == stop then
      pure b
    else
      fold (i-1) stop (← f (as.uget (i-1) lcProof) b)
  if start ≤ as.size then
    if stop < start then
      fold (USize.ofNat start) (USize.ofNat stop) init
    else
      pure init
  else if stop < as.size then
    fold (USize.ofNat as.size) (USize.ofNat stop) init
  else
    pure init

/-- Reference implementation for `foldrM` -/
@[implemented_by foldrMUnsafe]
def foldrM {α : Type u} {β : Type v} {m : Type v → Type w} [Monad m] (f : α → β → m β) (init : β) (as : Array α) (start := as.size) (stop := 0) : m β :=
  let rec fold (i : Nat) (h : i ≤ as.size) (b : β) : m β := do
    if i == stop then
      pure b
    else match i, h with
      | 0, _   => pure b
      | i+1, h =>
        have : i < as.size := Nat.lt_of_lt_of_le (Nat.lt_succ_self _) h
        fold i (Nat.le_of_lt this) (← f as[i] b)
  if h : start ≤ as.size then
    if stop < start then
      fold start h init
    else
      pure init
  else if stop < as.size then
    fold as.size (Nat.le_refl _) init
  else
    pure init

/-- See comment at `forInUnsafe` -/
@[inline]
unsafe def mapMUnsafe {α : Type u} {β : Type v} {m : Type v → Type w} [Monad m] (f : α → m β) (as : Array α) : m (Array β) :=
  let sz := USize.ofNat as.size
  let rec @[specialize] map (i : USize) (r : Array NonScalar) : m (Array PNonScalar.{v}) := do
    if i < sz then
     let v    := r.uget i lcProof
     -- Replace r[i] by `box(0)`.  This ensures that `v` remains unshared if possible.
     -- Note: we assume that arrays have a uniform representation irrespective
     -- of the element type, and that it is valid to store `box(0)` in any array.
     let r    := r.uset i default lcProof
     let vNew ← f (unsafeCast v)
     map (i+1) (r.uset i (unsafeCast vNew) lcProof)
    else
     pure (unsafeCast r)
  unsafeCast <| map 0 (unsafeCast as)

/-- Reference implementation for `mapM` -/
@[implemented_by mapMUnsafe]
def mapM {α : Type u} {β : Type v} {m : Type v → Type w} [Monad m] (f : α → m β) (as : Array α) : m (Array β) :=
  as.foldlM (fun bs a => do let b ← f a; pure (bs.push b)) (mkEmpty as.size)

@[inline]
def mapIdxM {α : Type u} {β : Type v} {m : Type v → Type w} [Monad m] (as : Array α) (f : Fin as.size → α → m β) : m (Array β) :=
  let rec @[specialize] map (i : Nat) (j : Nat) (inv : i + j = as.size) (bs : Array β) : m (Array β) := do
    match i, inv with
    | 0,    _  => pure bs
    | i+1, inv =>
      have : j < as.size := by
        rw [← inv, Nat.add_assoc, Nat.add_comm 1 j, Nat.add_comm]
        apply Nat.le_add_right
      let idx : Fin as.size := ⟨j, this⟩
      have : i + (j + 1) = as.size := by rw [← inv, Nat.add_comm j 1, Nat.add_assoc]
      map i (j+1) this (bs.push (← f idx (as.get idx)))
  map as.size 0 rfl (mkEmpty as.size)

@[inline]
def findSomeM? {α : Type u} {β : Type v} {m : Type v → Type w} [Monad m] (as : Array α) (f : α → m (Option β)) : m (Option β) := do
  for a in as do
    match (← f a) with
    | some b => return b
    | _      => pure ⟨⟩
  return none

@[inline]
def findM? {α : Type} {m : Type → Type} [Monad m] (as : Array α) (p : α → m Bool) : m (Option α) := do
  for a in as do
    if (← p a) then
      return a
  return none

@[inline]
def findIdxM? [Monad m] (as : Array α) (p : α → m Bool) : m (Option Nat) := do
  let mut i := 0
  for a in as do
    if (← p a) then
      return some i
    i := i + 1
  return none

@[inline]
unsafe def anyMUnsafe {α : Type u} {m : Type → Type w} [Monad m] (p : α → m Bool) (as : Array α) (start := 0) (stop := as.size) : m Bool :=
  let rec @[specialize] any (i : USize) (stop : USize) : m Bool := do
    if i == stop then
      pure false
    else
      if (← p (as.uget i lcProof)) then
        pure true
      else
        any (i+1) stop
  if start < stop then
    if stop ≤ as.size then
      any (USize.ofNat start) (USize.ofNat stop)
    else
      pure false
  else
    pure false

@[implemented_by anyMUnsafe]
def anyM {α : Type u} {m : Type → Type w} [Monad m] (p : α → m Bool) (as : Array α) (start := 0) (stop := as.size) : m Bool :=
  let any (stop : Nat) (h : stop ≤ as.size) :=
    let rec loop (j : Nat) : m Bool := do
      if hlt : j < stop then
        have : j < as.size := Nat.lt_of_lt_of_le hlt h
        if (← p as[j]) then
          pure true
        else
          loop (j+1)
      else
        pure false
    loop start
  if h : stop ≤ as.size then
    any stop h
  else
    any as.size (Nat.le_refl _)
termination_by loop i j => stop - j

@[inline]
def allM {α : Type u} {m : Type → Type w} [Monad m] (p : α → m Bool) (as : Array α) (start := 0) (stop := as.size) : m Bool :=
  return !(← as.anyM (start := start) (stop := stop) fun v => return !(← p v))

@[inline]
def findSomeRevM? {α : Type u} {β : Type v} {m : Type v → Type w} [Monad m] (as : Array α) (f : α → m (Option β)) : m (Option β) :=
  let rec @[specialize] find : (i : Nat) → i ≤ as.size → m (Option β)
    | 0,   _ => pure none
    | i+1, h => do
      have : i < as.size := Nat.lt_of_lt_of_le (Nat.lt_succ_self _) h
      let r ← f as[i]
      match r with
      | some _ => pure r
      | none   =>
        have : i ≤ as.size := Nat.le_of_lt this
        find i this
  find as.size (Nat.le_refl _)

@[inline]
def findRevM? {α : Type} {m : Type → Type w} [Monad m] (as : Array α) (p : α → m Bool) : m (Option α) :=
  as.findSomeRevM? fun a => return if (← p a) then some a else none

@[inline]
def forM {α : Type u} {m : Type v → Type w} [Monad m] (f : α → m PUnit) (as : Array α) (start := 0) (stop := as.size) : m PUnit :=
  as.foldlM (fun _ => f) ⟨⟩ start stop

@[inline]
def forRevM {α : Type u} {m : Type v → Type w} [Monad m] (f : α → m PUnit) (as : Array α) (start := as.size) (stop := 0) : m PUnit :=
  as.foldrM (fun a _ => f a) ⟨⟩ start stop

@[inline]
def foldl {α : Type u} {β : Type v} (f : β → α → β) (init : β) (as : Array α) (start := 0) (stop := as.size) : β :=
  Id.run <| as.foldlM f init start stop

@[inline]
def foldr {α : Type u} {β : Type v} (f : α → β → β) (init : β) (as : Array α) (start := as.size) (stop := 0) : β :=
  Id.run <| as.foldrM f init start stop

@[inline]
def map {α : Type u} {β : Type v} (f : α → β) (as : Array α) : Array β :=
  Id.run <| as.mapM f

@[inline]
def mapIdx {α : Type u} {β : Type v} (as : Array α) (f : Fin as.size → α → β) : Array β :=
  Id.run <| as.mapIdxM f

@[inline]
def find? {α : Type} (as : Array α) (p : α → Bool) : Option α :=
  Id.run <| as.findM? p

@[inline]
def findSome? {α : Type u} {β : Type v} (as : Array α) (f : α → Option β) : Option β :=
  Id.run <| as.findSomeM? f

@[inline]
def findSome! {α : Type u} {β : Type v} [Inhabited β] (a : Array α) (f : α → Option β) : β :=
  match findSome? a f with
  | some b => b
  | none   => panic! "failed to find element"

@[inline]
def findSomeRev? {α : Type u} {β : Type v} (as : Array α) (f : α → Option β) : Option β :=
  Id.run <| as.findSomeRevM? f

@[inline]
def findRev? {α : Type} (as : Array α) (p : α → Bool) : Option α :=
  Id.run <| as.findRevM? p

@[inline]
def findIdx? {α : Type u} (as : Array α) (p : α → Bool) : Option Nat :=
  let rec loop (i : Nat) (j : Nat) (inv : i + j = as.size) : Option Nat :=
    if hlt : j < as.size then
      match i, inv with
      | 0, inv => by
        apply False.elim
        rw [Nat.zero_add] at inv
        rw [inv] at hlt
        exact absurd hlt (Nat.lt_irrefl _)
      | i+1, inv =>
        if p as[j] then
          some j
        else
          have : i + (j+1) = as.size := by
            rw [← inv, Nat.add_comm j 1, Nat.add_assoc]
          loop i (j+1) this
    else
      none
  loop as.size 0 rfl

def getIdx? [BEq α] (a : Array α) (v : α) : Option Nat :=
a.findIdx? fun a => a == v

@[inline]
def any (as : Array α) (p : α → Bool) (start := 0) (stop := as.size) : Bool :=
  Id.run <| as.anyM p start stop

@[inline]
def all (as : Array α) (p : α → Bool) (start := 0) (stop := as.size) : Bool :=
  Id.run <| as.allM p start stop

def contains [BEq α] (as : Array α) (a : α) : Bool :=
  as.any fun b => a == b

def elem [BEq α] (a : α) (as : Array α) : Bool :=
  as.contains a

@[inline] def getEvenElems (as : Array α) : Array α :=
  (·.2) <| as.foldl (init := (true, Array.empty)) fun (even, r) a =>
    if even then
      (false, r.push a)
    else
      (true, r)

@[export lean_array_to_list]
def toList (as : Array α) : List α :=
  as.foldr List.cons []

instance {α : Type u} [Repr α] : Repr (Array α) where
  reprPrec a _ :=
    let _ : Std.ToFormat α := ⟨repr⟩
    if a.size == 0 then
      "#[]"
    else
      Std.Format.bracketFill "#[" (Std.Format.joinSep (toList a) ("," ++ Std.Format.line)) "]"

instance [ToString α] : ToString (Array α) where
  toString a := "#" ++ toString a.toList

protected def append (as : Array α) (bs : Array α) : Array α :=
  bs.foldl (init := as) fun r v => r.push v

instance : Append (Array α) := ⟨Array.append⟩

protected def appendList (as : Array α) (bs : List α) : Array α :=
  bs.foldl (init := as) fun r v => r.push v

instance : HAppend (Array α) (List α) (Array α) := ⟨Array.appendList⟩

@[inline]
def concatMapM [Monad m] (f : α → m (Array β)) (as : Array α) : m (Array β) :=
  as.foldlM (init := empty) fun bs a => do return bs ++ (← f a)

@[inline]
def concatMap (f : α → Array β) (as : Array α) : Array β :=
  as.foldl (init := empty) fun bs a => bs ++ f a

end Array

export Array (mkArray)

syntax "#[" withoutPosition(sepBy(term, ", ")) "]" : term

macro_rules
  | `(#[ $elems,* ]) => `(List.toArray [ $elems,* ])

namespace Array

-- TODO(Leo): cleanup
@[specialize]
def isEqvAux (a b : Array α) (hsz : a.size = b.size) (p : α → α → Bool) (i : Nat) : Bool :=
  if h : i < a.size then
     have : i < b.size := hsz ▸ h
     p a[i] b[i] && isEqvAux a b hsz p (i+1)
  else
    true
termination_by _ => a.size - i

@[inline] def isEqv (a b : Array α) (p : α → α → Bool) : Bool :=
  if h : a.size = b.size then
    isEqvAux a b h p 0
  else
    false

instance [BEq α] : BEq (Array α) :=
  ⟨fun a b => isEqv a b BEq.beq⟩

@[inline]
def filter (p : α → Bool) (as : Array α) (start := 0) (stop := as.size) : Array α :=
  as.foldl (init := #[]) (start := start) (stop := stop) fun r a =>
    if p a then r.push a else r

@[inline]
def filterM [Monad m] (p : α → m Bool) (as : Array α) (start := 0) (stop := as.size) : m (Array α) :=
  as.foldlM (init := #[]) (start := start) (stop := stop) fun r a => do
    if (← p a) then return r.push a else return r

@[specialize]
def filterMapM [Monad m] (f : α → m (Option β)) (as : Array α) (start := 0) (stop := as.size) : m (Array β) :=
  as.foldlM (init := #[]) (start := start) (stop := stop) fun bs a => do
    match (← f a) with
    | some b => pure (bs.push b)
    | none   => pure bs

@[inline]
def filterMap (f : α → Option β) (as : Array α) (start := 0) (stop := as.size) : Array β :=
  Id.run <| as.filterMapM f (start := start) (stop := stop)

@[specialize]
def getMax? (as : Array α) (lt : α → α → Bool) : Option α :=
  if h : 0 < as.size then
    let a0 := as[0]
    some <| as.foldl (init := a0) (start := 1) fun best a =>
      if lt best a then a else best
  else
    none

@[inline]
def partition (p : α → Bool) (as : Array α) : Array α × Array α := Id.run do
  let mut bs := #[]
  let mut cs := #[]
  for a in as do
    if p a then
      bs := bs.push a
    else
      cs := cs.push a
  return (bs, cs)

theorem ext (a b : Array α)
    (h₁ : a.size = b.size)
    (h₂ : (i : Nat) → (hi₁ : i < a.size) → (hi₂ : i < b.size) → a[i] = b[i])
    : a = b := by
  let rec extAux (a b : List α)
      (h₁ : a.length = b.length)
      (h₂ : (i : Nat) → (hi₁ : i < a.length) → (hi₂ : i < b.length) → a.get ⟨i, hi₁⟩ = b.get ⟨i, hi₂⟩)
      : a = b := by
    induction a generalizing b with
    | nil =>
      cases b with
      | nil       => rfl
      | cons b bs => rw [List.length_cons] at h₁; injection h₁
    | cons a as ih =>
      cases b with
      | nil => rw [List.length_cons] at h₁; injection h₁
      | cons b bs =>
        have hz₁ : 0 < (a::as).length := by rw [List.length_cons]; apply Nat.zero_lt_succ
        have hz₂ : 0 < (b::bs).length := by rw [List.length_cons]; apply Nat.zero_lt_succ
        have headEq : a = b := h₂ 0 hz₁ hz₂
        have h₁' : as.length = bs.length := by rw [List.length_cons, List.length_cons] at h₁; injection h₁
        have h₂' : (i : Nat) → (hi₁ : i < as.length) → (hi₂ : i < bs.length) → as.get ⟨i, hi₁⟩ = bs.get ⟨i, hi₂⟩ := by
          intro i hi₁ hi₂
          have hi₁' : i+1 < (a::as).length := by rw [List.length_cons]; apply Nat.succ_lt_succ; assumption
          have hi₂' : i+1 < (b::bs).length := by rw [List.length_cons]; apply Nat.succ_lt_succ; assumption
          have : (a::as).get ⟨i+1, hi₁'⟩ = (b::bs).get ⟨i+1, hi₂'⟩ := h₂ (i+1) hi₁' hi₂'
          apply this
        have tailEq : as = bs := ih bs h₁' h₂'
        rw [headEq, tailEq]
  cases a; cases b
  apply congrArg
  apply extAux
  assumption
  assumption

theorem extLit {n : Nat}
    (a b : Array α)
    (hsz₁ : a.size = n) (hsz₂ : b.size = n)
    (h : (i : Nat) → (hi : i < n) → a.getLit i hsz₁ hi = b.getLit i hsz₂ hi) : a = b :=
  Array.ext a b (hsz₁.trans hsz₂.symm) fun i hi₁ _ => h i (hsz₁ ▸ hi₁)

end Array

-- CLEANUP the following code
namespace Array

def indexOfAux [BEq α] (a : Array α) (v : α) (i : Nat) : Option (Fin a.size) :=
  if h : i < a.size then
    let idx : Fin a.size := ⟨i, h⟩;
    if a.get idx == v then some idx
    else indexOfAux a v (i+1)
  else none
termination_by _ => a.size - i

def indexOf? [BEq α] (a : Array α) (v : α) : Option (Fin a.size) :=
  indexOfAux a v 0

@[simp] theorem size_swap (a : Array α) (i j : Fin a.size) : (a.swap i j).size = a.size := by
  show ((a.set i (a.get j)).set (size_set a i _ ▸ j) (a.get i)).size = a.size
  rw [size_set, size_set]

@[simp] theorem size_pop (a : Array α) : a.pop.size = a.size - 1 := by
  match a with
  | ⟨[]⟩ => rfl
  | ⟨a::as⟩ => simp [pop, Nat.succ_sub_succ_eq_sub, size]

theorem reverse.termination {i j : Nat} (h : i < j) : j - 1 - (i + 1) < j - i := by
  rw [Nat.sub_sub, Nat.add_comm]
  exact Nat.lt_of_le_of_lt (Nat.pred_le _) (Nat.sub_succ_lt_self _ _ h)

def reverse (as : Array α) : Array α :=
  if h : as.size ≤ 1 then
    as
  else
    loop as 0 ⟨as.size - 1, Nat.pred_lt (mt (fun h : as.size = 0 => h ▸ by decide) h)⟩
where
  loop (as : Array α) (i : Nat) (j : Fin as.size) :=
    if h : i < j then
      have := reverse.termination h
      let as := as.swap ⟨i, Nat.lt_trans h j.2⟩ j
      have : j-1 < as.size := by rw [size_swap]; exact Nat.lt_of_le_of_lt (Nat.pred_le _) j.2
      loop as (i+1) ⟨j-1, this⟩
    else
      as
termination_by _ => j - i

def popWhile (p : α → Bool) (as : Array α) : Array α :=
  if h : as.size > 0 then
    if p (as.get ⟨as.size - 1, Nat.sub_lt h (by decide)⟩) then
      popWhile p as.pop
    else
      as
  else
    as
termination_by popWhile as => as.size

def takeWhile (p : α → Bool) (as : Array α) : Array α :=
  let rec go (i : Nat) (r : Array α) : Array α :=
    if h : i < as.size then
      let a := as.get ⟨i, h⟩
      if p a then
        go (i+1) (r.push a)
      else
        r
    else
      r
  go 0 #[]
termination_by go i r => as.size - i

def eraseIdxAux (i : Nat) (a : Array α) : Array α :=
  if h : i < a.size then
    let idx  : Fin a.size := ⟨i, h⟩;
    let idx1 : Fin a.size := ⟨i - 1, by exact Nat.lt_of_le_of_lt (Nat.pred_le i) h⟩;
    let a' := a.swap idx idx1
    eraseIdxAux (i+1) a'
  else
    a.pop
termination_by _ => a.size - i

def feraseIdx (a : Array α) (i : Fin a.size) : Array α :=
  eraseIdxAux (i.val + 1) a

def eraseIdx (a : Array α) (i : Nat) : Array α :=
  if i < a.size then eraseIdxAux (i+1) a else a

def eraseIdxSzAux (a : Array α) (i : Nat) (r : Array α) (heq : r.size = a.size) : { r : Array α // r.size = a.size - 1 } :=
  if h : i < r.size then
    let idx  : Fin r.size := ⟨i, h⟩;
    let idx1 : Fin r.size := ⟨i - 1, by exact Nat.lt_of_le_of_lt (Nat.pred_le i) h⟩;
    eraseIdxSzAux a (i+1) (r.swap idx idx1) ((size_swap r idx idx1).trans heq)
  else
    ⟨r.pop, (size_pop r).trans (heq ▸ rfl)⟩
termination_by _ => r.size - i

def eraseIdx' (a : Array α) (i : Fin a.size) : { r : Array α // r.size = a.size - 1 } :=
  eraseIdxSzAux a (i.val + 1) a rfl

def erase [BEq α] (as : Array α) (a : α) : Array α :=
  match as.indexOf? a with
  | none   => as
  | some i => as.feraseIdx i

/-- Insert element `a` at position `i`. -/
@[inline] def insertAt (as : Array α) (i : Fin (as.size + 1)) (a : α) : Array α :=
  let rec loop (as : Array α) (j : Fin as.size) :=
    if i.1 < j then
      let j' := ⟨j-1, Nat.lt_of_le_of_lt (Nat.pred_le _) j.2⟩
      let as := as.swap j' j
      loop as ⟨j', by rw [size_swap]; exact j'.2⟩
    else
      as
  let j := as.size
  let as := as.push a
  loop as ⟨j, size_push .. ▸ j.lt_succ_self⟩
termination_by loop j => j.1

/-- Insert element `a` at position `i`. Panics if `i` is not `i ≤ as.size`. -/
def insertAt! (as : Array α) (i : Nat) (a : α) : Array α :=
  if h : i ≤ as.size then
    insertAt as ⟨i, Nat.lt_succ_of_le h⟩ a
  else panic! "invalid index"

def toListLitAux (a : Array α) (n : Nat) (hsz : a.size = n) : ∀ (i : Nat), i ≤ a.size → List α → List α
  | 0,     _,  acc => acc
  | (i+1), hi, acc => toListLitAux a n hsz i (Nat.le_of_succ_le hi) (a.getLit i hsz (Nat.lt_of_lt_of_eq (Nat.lt_of_lt_of_le (Nat.lt_succ_self i) hi) hsz) :: acc)

def toArrayLit (a : Array α) (n : Nat) (hsz : a.size = n) : Array α :=
  List.toArray <| toListLitAux a n hsz n (hsz ▸ Nat.le_refl _) []

theorem ext' {as bs : Array α} (h : as.data = bs.data) : as = bs := by
  cases as; cases bs; simp at h; rw [h]

theorem toArrayAux_eq (as : List α) (acc : Array α) : (as.toArrayAux acc).data = acc.data ++ as := by
  induction as generalizing acc <;> simp [*, List.toArrayAux, Array.push, List.append_assoc, List.concat_eq_append]

theorem data_toArray (as : List α) : as.toArray.data = as := by
  simp [List.toArray, toArrayAux_eq, Array.mkEmpty]

theorem toArrayLit_eq (as : Array α) (n : Nat) (hsz : as.size = n) : as = toArrayLit as n hsz := by
  apply ext'
  simp [toArrayLit, data_toArray]
  have hle : n ≤ as.size := hsz ▸ Nat.le_refl _
  have hge : as.size ≤ n := hsz ▸ Nat.le_refl _
  have := go n hle
  rw [List.drop_eq_nil_of_le hge] at this
  rw [this]
where
  getLit_eq (as : Array α) (i : Nat) (h₁ : as.size = n) (h₂ : i < n) : as.getLit i h₁ h₂ = getElem as.data i ((id (α := as.data.length = n) h₁) ▸ h₂) :=
    rfl

  go (i : Nat) (hi : i ≤ as.size) : toListLitAux as n hsz i hi (as.data.drop i) = as.data := by
    cases i <;> simp [getLit_eq, List.get_drop_eq_drop, toListLitAux, List.drop, go]

def isPrefixOfAux [BEq α] (as bs : Array α) (hle : as.size ≤ bs.size) (i : Nat) : Bool :=
  if h : i < as.size then
    let a := as[i]
    have : i < bs.size := Nat.lt_of_lt_of_le h hle
    let b := bs[i]
    if a == b then
      isPrefixOfAux as bs hle (i+1)
    else
      false
  else
    true
termination_by _ => as.size - i

/-- Return true iff `as` is a prefix of `bs`.
That is, `bs = as ++ t` for some `t : List α`.-/
def isPrefixOf [BEq α] (as bs : Array α) : Bool :=
  if h : as.size ≤ bs.size then
    isPrefixOfAux as bs h 0
  else
    false

private def allDiffAuxAux [BEq α] (as : Array α) (a : α) : forall (i : Nat), i < as.size → Bool
  | 0,   _ => true
  | i+1, h =>
    have : i < as.size := Nat.lt_trans (Nat.lt_succ_self _) h;
    a != as[i] && allDiffAuxAux as a i this

private def allDiffAux [BEq α] (as : Array α) (i : Nat) : Bool :=
  if h : i < as.size then
    allDiffAuxAux as as[i] i h && allDiffAux as (i+1)
  else
    true
termination_by _ => as.size - i

def allDiff [BEq α] (as : Array α) : Bool :=
  allDiffAux as 0

@[specialize] def zipWithAux (f : α → β → γ) (as : Array α) (bs : Array β) (i : Nat) (cs : Array γ) : Array γ :=
  if h : i < as.size then
    let a := as[i]
    if h : i < bs.size then
      let b := bs[i]
      zipWithAux f as bs (i+1) <| cs.push <| f a b
    else
      cs
  else
    cs
termination_by _ => as.size - i

@[inline] def zipWith (as : Array α) (bs : Array β) (f : α → β → γ) : Array γ :=
  zipWithAux f as bs 0 #[]

def zip (as : Array α) (bs : Array β) : Array (α × β) :=
  zipWith as bs Prod.mk

def unzip (as : Array (α × β)) : Array α × Array β :=
  as.foldl (init := (#[], #[])) fun (as, bs) (a, b) => (as.push a, bs.push b)

def split (as : Array α) (p : α → Bool) : Array α × Array α :=
  as.foldl (init := (#[], #[])) fun (as, bs) a =>
    if p a then (as.push a, bs) else (as, bs.push a)

-/
