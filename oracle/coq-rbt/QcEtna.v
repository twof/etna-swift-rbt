(* The `-=>` (Implies) and `==?` (PolymorphicEquality) operators used by the
   ETNA workload's Spec.v. These live in the ETNA *fork* of QuickChick
   (src/Decidability.v), not in released coq-quickchick. Copied here VERBATIM
   from that fork so the authors' Impl.v / Spec.v compile and evaluate unchanged.
   (The fork's only other additions are the FuzzChick fuzzer, which an oracle
   that Computes properties on concrete inputs does not use.) *)

Require Import ZArith.
From Coq Require Import Bool List.
Local Open Scope Z_scope.

Class Implies (A B : Type) := implies : A -> B -> option bool.
Notation "A -=> B" := (implies A B) (at level 199, left associativity).

#[global] Instance impliesOO : Implies (option bool) (option bool) :=
  fun p1 p2 =>
    match p1 with
    | None | Some false => None
    | Some true => p2
    end.
#[global] Instance impliesBB : Implies bool bool :=
  fun p1 p2 => impliesOO (Some p1) (Some p2).
#[global] Instance impliesOB : Implies (option bool) bool :=
  fun p1 p2 => impliesOO p1 (Some p2).
#[global] Instance impliesBO : Implies bool (option bool) :=
  fun p1 p2 => impliesOO (Some p1) p2.

Class PolymorphicEquality (A: Type) := poly_eqb : A -> A -> bool.
Notation "A ==? B" := (poly_eqb A B) (at level 199, left associativity).

#[global] Instance nat_eqb : PolymorphicEquality nat :=
  fun a b => Nat.eqb a b.
#[global] Instance z_eqb : PolymorphicEquality Z :=
  fun a b => Zeq_bool a b.
#[global] Instance option_eqb {A} `{PolymorphicEquality A} : PolymorphicEquality (option A) :=
  fun o1 o2 =>
    match o1, o2 with
    | None, None => true
    | None, _ => false
    | _, None => false
    | Some x, Some y => x ==? y
    end.
#[global] Instance list_eqb {A} `{PolymorphicEquality A} : PolymorphicEquality (list A) :=
  fix aux l1 l2 :=
    match l1, l2 with
    | nil, nil => true
    | nil, _ => false
    | _, nil => false
    | x::xs, y::ys => (x ==? y) && aux xs ys
    end.
#[global] Instance pair_eqb {A B} `{PolymorphicEquality A} `{PolymorphicEquality B} : PolymorphicEquality (A * B) :=
  fun p1 p2 => (fst p1 ==? fst p2) && (snd p1 ==? snd p2).
