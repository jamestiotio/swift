// RUN: %target-typecheck-verify-swift -enable-experimental-feature NoncopyableGenerics

// REQUIRES: asserts

// Check support for explicit conditional conformance
public struct ExplicitCond<T: ~Copyable>: ~Copyable {}
extension ExplicitCond: Copyable where T: Copyable {}
// expected-note@-1 {{requirement from conditional conformance}}
// expected-note@-2 {{requirement from conditional conformance of 'ExplicitCondAlias<NC>' (aka 'ExplicitCond<NC>') to 'Copyable'}}

public typealias ExplicitCondAlias<T> = ExplicitCond<T> where T: ~Copyable
public typealias AlwaysCopyable<T> = ExplicitCond<T>

func checkCopyable<T>(_ t: T) {} // expected-note {{generic parameter 'T' has an implicit Copyable requirement}}

func test<C, NC: ~Copyable>(
  _ a1: ExplicitCond<C>, _ b1: borrowing ExplicitCond<NC>,
  _ a2: ExplicitCondAlias<C>, _ b2: borrowing ExplicitCondAlias<NC>
  ) {
  checkCopyable(a1)
  checkCopyable(b1) // expected-error {{global function 'checkCopyable' requires that 'NC' conform to 'Copyable'}}
  checkCopyable(a2)
  checkCopyable(b2) // expected-error {{global function 'checkCopyable' requires that 'NC' conform to 'Copyable'}}
}

func checkAliases<C, NC: ~Copyable>(_ a: AlwaysCopyable<C>, _ b: AlwaysCopyable<NC>) {
// expected-error@-1 {{'NC' required to be 'Copyable' but is marked with '~Copyable'}}
  checkCopyable(a)
  checkCopyable(b)
}

struct TryInferCopyable: ~Copyable, NeedsCopyable {}
// expected-error@-1 {{type 'TryInferCopyable' does not conform to protocol 'NeedsCopyable'}}
// expected-error@-2 {{type 'TryInferCopyable' does not conform to protocol 'Copyable'}}

protocol Removed: ~Copyable {
  func requiresCopyableSelf(_ t: AlwaysCopyable<Self>)
  // expected-error@-1 {{type 'Self' does not conform to protocol 'Copyable'}}
}
protocol Plain<T> {
  associatedtype T: ~Copyable
  func requiresCopyableSelf(_ t: AlwaysCopyable<Self>)
  func requiresCopyableT(_ t: AlwaysCopyable<T>)
  // expected-error@-1 {{type 'Self.T' does not conform to protocol 'Copyable'}}
}

protocol RemovedAgain where Self: ~Copyable {
    func requiresCopyableSelf(_ t: AlwaysCopyable<Self>) // expected-error {{type 'Self' does not conform to protocol 'Copyable'}}
}

struct StructContainment<T: ~Copyable> : Copyable {
    var storage: Maybe<T>
    // expected-error@-1 {{stored property 'storage' of 'Copyable'-conforming generic struct 'StructContainment' has noncopyable type 'Maybe<T>'}}
}

enum EnumContainment<T: ~Copyable> : Copyable {
    // expected-note@-1 {{'T' has '~Copyable' constraint preventing implicit 'Copyable' conformance}}

    case some(T) // expected-error {{associated value 'some' of 'Copyable'-conforming generic enum 'EnumContainment' has noncopyable type 'T'}}
    case other(Int)
    case none
}

class ClassContainment<T: ~Copyable> {
    var storage: T
    init(_ t: consuming T) {
        storage = t
        checkCopyable(t) // expected-error {{noncopyable type 'T' cannot be substituted for copyable generic parameter 'T' in 'checkCopyable'}}
    }

    deinit {}
}

// expected-note@+2 {{generic struct 'ConditionalContainment' has '~Copyable' constraint on a generic parameter, making its 'Copyable' conformance conditional}}
// expected-note@+1 {{consider adding '~Copyable' to generic struct 'ConditionalContainment'}}{{45-45=: ~Copyable}}
struct ConditionalContainment<T: ~Copyable> {
  var x: T
  var y: NC // expected-error {{stored property 'y' of 'Copyable'-conforming generic struct 'ConditionalContainment' has noncopyable type 'NC'}}
}

func chk(_ T: RequireCopyable<ConditionalContainment<Int>>) {}


/// ----------------

struct AlwaysCopyableDeinit<T: ~Copyable> : Copyable {
  let nc: NC // expected-error {{stored property 'nc' of 'Copyable'-conforming generic struct 'AlwaysCopyableDeinit' has noncopyable type 'NC'}}
  deinit {} // expected-error {{deinitializer cannot be declared in generic struct 'AlwaysCopyableDeinit' that conforms to 'Copyable'}}
}

struct SometimesCopyableDeinit<T: ~Copyable> : ~Copyable {
  deinit {} // expected-error {{deinitializer cannot be declared in generic struct 'SometimesCopyableDeinit' that conforms to 'Copyable'}}
}
extension SometimesCopyableDeinit: Copyable where T: Copyable {}

struct NeverCopyableDeinit<T: ~Copyable>: ~Copyable {
  deinit {}
}

/// ---------------

// expected-note@+2 {{consider adding '~Copyable' to generic enum 'Maybe'}}
// expected-note@+1 2{{generic enum 'Maybe' has '~Copyable' constraint on a generic parameter, making its 'Copyable' conformance conditional}}
enum Maybe<Wrapped: ~Copyable> {
  case just(Wrapped)
  case none

  deinit {} // expected-error {{deinitializer cannot be declared in generic enum 'Maybe' that conforms to 'Copyable'}}
  // expected-error@-1 {{deinitializers are not yet supported on noncopyable enums}}
}

// expected-note@+4{{requirement specified as 'NC' : 'Copyable'}}
// expected-note@+3{{requirement from conditional conformance of 'Maybe<NC>' to 'Copyable'}}
// expected-note@+2{{requirement specified as 'Wrapped' : 'Copyable'}}
// expected-note@+1{{requirement from conditional conformance of 'Maybe<Wrapped>' to 'Copyable'}}
struct RequireCopyable<T> {
  // expected-note@-1 {{consider adding '~Copyable' to generic struct 'RequireCopyable'}}{{27-27=: ~Copyable}}
  deinit {} // expected-error {{deinitializer cannot be declared in generic struct 'RequireCopyable' that conforms to 'Copyable'}}
}

struct NC: ~Copyable {
// expected-note@-1 3{{struct 'NC' has '~Copyable' constraint preventing 'Copyable' conformance}}
  deinit {}
}

typealias ok1 = RequireCopyable<Int>
typealias ok2 = RequireCopyable<Maybe<Int>>

typealias err1 = RequireCopyable<Maybe<NC>>
// expected-error@-1{{type 'NC' does not conform to protocol 'Copyable'}}
// expected-error@-2{{'RequireCopyable' requires that 'NC' conform to 'Copyable'}}

typealias err2 = RequireCopyable<NC>
// expected-error@-1{{type 'NC' does not conform to protocol 'Copyable'}}

// plain extension doesn't treat Self as Copyable
extension Maybe {
  func check1(_ t: RequireCopyable<Self>) {}
  // expected-error@-1 {{type 'Wrapped' does not conform to protocol 'Copyable'}}
  // expected-error@-2 {{'RequireCopyable' requires that 'Wrapped' conform to 'Copyable'}}
}

extension Maybe where Self: Copyable {
  func check2(_ t: RequireCopyable<Self>) {}
}

// expected-note@+2 {{generic struct 'CornerCase' has '~Copyable' constraint on a generic parameter, making its 'Copyable' conformance conditional}}
// expected-note@+1 {{consider adding '~Copyable' to generic struct 'CornerCase'}}{{33-33=: ~Copyable}}
struct CornerCase<T: ~Copyable> {
  let t: T
  let nc: NC // expected-error {{stored property 'nc' of 'Copyable'-conforming generic struct 'CornerCase' has noncopyable type 'NC'}}
}

func chk(_ t: CornerCase<NC>) {}
// expected-error@-1 {{parameter of noncopyable type 'CornerCase<NC>' must specify ownership}}
// expected-note@-2 3{{add}}


/// MARK: tests that we diagnose ~Copyable that became invalid because it's required to be copyable

protocol NeedsCopyable {}

struct Silly: ~Copyable, Copyable {} // expected-error {{struct 'Silly' required to be 'Copyable' but is marked with '~Copyable'}}
enum Sally: Copyable, ~Copyable, NeedsCopyable {} // expected-error {{enum 'Sally' required to be 'Copyable' but is marked with '~Copyable'}}
class NiceTry: ~Copyable, Copyable {} // expected-error {{classes cannot be noncopyable}}

struct OopsConformance1: ~Copyable, NeedsCopyable {}
// expected-error@-1 {{type 'OopsConformance1' does not conform to protocol 'NeedsCopyable'}}
// expected-error@-2 {{type 'OopsConformance1' does not conform to protocol 'Copyable'}}


struct Extendo: ~Copyable {}
extension Extendo: Copyable, ~Copyable {} // expected-error {{cannot apply inverse '~Copyable' to extension}}

enum EnumExtendo {}
extension EnumExtendo: ~Copyable {} // expected-error {{cannot apply inverse '~Copyable' to extension}}

extension NeedsCopyable where Self: ~Copyable {}
// expected-error@-1 {{cannot add inverse constraint 'Self: ~Copyable' on generic parameter 'Self' defined in outer scope}}
// expected-error@-2 {{'Self' required to be 'Copyable' but is marked with '~Copyable'}}

protocol NoCopyP: ~Copyable {}

func needsCopyable<T>(_ t: T) {} // expected-note 2{{generic parameter 'T' has an implicit Copyable requirement}}
func noCopyable(_ t: borrowing some ~Copyable) {}
func noCopyableAndP(_ t: borrowing some NoCopyP & ~Copyable) {}

func openingExistentials(_ a: borrowing any NoCopyP & ~Copyable,
                         _ b: any NoCopyP,
                         _ nc: borrowing any ~Copyable) {
  needsCopyable(a) // expected-error {{noncopyable type 'any NoCopyP & ~Copyable' cannot be substituted for copyable generic parameter 'T' in 'needsCopyable'}}
  noCopyable(a)
  noCopyableAndP(a)

  needsCopyable(b)
  noCopyable(b)
  noCopyableAndP(b)

  needsCopyable(nc) // expected-error {{noncopyable type 'any ~Copyable' cannot be substituted for copyable generic parameter 'T' in 'needsCopyable'}}
  noCopyable(nc)
  noCopyableAndP(nc) // expected-error {{global function 'noCopyableAndP' requires that 'some NoCopyP & ~Copyable' conform to 'NoCopyP'}}
}

func project<CurValue>(_ base: CurValue) { }
func testSpecial(_ a: Any) {
  _openExistential(a, do: project)
}


func conflict1<T>(_ t: T) where T: NeedsCopyable, T: ~Copyable {}
// expected-error@-1 {{'T' required to be 'Copyable' but is marked with '~Copyable'}}

func conflict2<T: ~Copyable>(_ t: AlwaysCopyable<T>) {}
// expected-error@-1 {{'T' required to be 'Copyable' but is marked with '~Copyable'}}

func conflict3<T: NeedsCopyable & ~Copyable>(_ t: T) {}
// expected-error@-1 {{'T' required to be 'Copyable' but is marked with '~Copyable'}}

func conflict4(_ t: some NeedsCopyable & ~Copyable) {}
// expected-error@-1 {{'some NeedsCopyable & ~Copyable' required to be 'Copyable' but is marked with '~Copyable'}}

protocol Conflict5: ~Copyable {
  func whatever() -> AlwaysCopyable<Self> // expected-error {{type 'Self' does not conform to protocol 'Copyable'}}
}

// expected-warning@+1 {{same-type requirement makes generic parameters 'U' and 'T' equivalent}}
func conflict6<T: ~Copyable, U>(_ t: T, _ u: U) // expected-error {{'T' required to be 'Copyable' but is marked with '~Copyable'}}
 where U : NeedsCopyable, T == U {}

protocol Conflict7 {
  associatedtype Element
}

func conflict7<T, U>(_ t: T, _ u: U)
  where
    U: ~Copyable,  // expected-error {{'U' required to be 'Copyable' but is marked with '~Copyable'}}
    T: Conflict7,
    U == T.Element
  {}

protocol Conflict8: ~Copyable, NeedsCopyable {}
// expected-error@-1 {{'Self' required to be 'Copyable' but is marked with '~Copyable'}}

struct Conflict9<T: NeedsCopyable> {}
func conflict9<U: ~Copyable>(_ u: Conflict9<U>) {}
// expected-error@-1 {{'U' required to be 'Copyable' but is marked with '~Copyable'}}

func conflict10<T>(_ t: T, _ u: some ~Copyable & Copyable)
// expected-error@-1 {{'some ~Copyable & Copyable' required to be 'Copyable' but is marked with '~Copyable'}}
  where T: Copyable,
        T: ~Copyable {}
// expected-error@-1 {{'T' required to be 'Copyable' but is marked with '~Copyable'}}

// FIXME: this is bogus (rdar://119345796)
protocol Conflict11: ~Copyable, Copyable {}

struct Conflict12: ~Copyable, Copyable {}
// expected-error@-1 {{struct 'Conflict12' required to be 'Copyable' but is marked with '~Copyable'}}

// FIXME: this is bogus (rdar://119346022)
protocol Conflict13 {
  associatedtype A
  associatedtype B: ~Copyable
}
func conflict13<T>(_ t: T)
  where T: Conflict13,
        T.A == T.B
        {}
