Require Import ZArith String.
From RBT Require Import QcEtna Spec Impl.
Local Open Scope Z_scope.

(* 38 witnesses *)
Compute ("delete_4/DeleteDelete"%string, prop_DeleteDelete (T B (T B E (-1) 0 E) 0 3 (T B E 3 0 E)) (-1) 0).
Compute ("delete_4/DeleteModel"%string, prop_DeleteModel (T B E 1 0 E) 0).
Compute ("delete_4/DeletePost"%string, prop_DeletePost (T B E 0 0 E) 1 0).
Compute ("delete_4/DeleteInsert"%string, prop_DeleteInsert E 0 1 0).
Compute ("delete_4/InsertDelete"%string, prop_InsertDelete E 0 0 0).
Compute ("insert_1/InsertPost"%string, prop_InsertPost (T B E (-1) 1 E) 0 (-1) 0).
Compute ("insert_1/InsertModel"%string, prop_InsertModel (T B E 1 0 E) 0 0).
Compute ("insert_1/DeleteInsert"%string, prop_DeleteInsert (T B E 0 0 E) (-3) (-3) 0).
Compute ("insert_1/InsertInsert"%string, prop_InsertInsert E 0 1 0 0).
Compute ("insert_2/InsertPost"%string, prop_InsertPost (T B E (-1) 1 E) 0 0 0).
Compute ("insert_2/InsertModel"%string, prop_InsertModel (T B E 0 0 E) 1 0).
Compute ("insert_2/InsertDelete"%string, prop_InsertDelete E 0 0 0).
Compute ("insert_2/DeleteInsert"%string, prop_DeleteInsert (T B E (-1) 0 E) 0 0 1).
Compute ("insert_2/InsertInsert"%string, prop_InsertInsert E 1 0 1 0).
Compute ("insert_3/InsertPost"%string, prop_InsertPost (T B E 0 1 E) 0 0 0).
Compute ("insert_3/InsertModel"%string, prop_InsertModel (T B E (-1) 1 E) (-1) 0).
Compute ("insert_3/InsertDelete"%string, prop_InsertDelete E 0 0 0).
Compute ("insert_3/InsertInsert"%string, prop_InsertInsert E 3 3 0 1).
Compute ("delete_5/DeleteModel"%string, prop_DeleteModel (T B (T B E (-2) 1 E) 0 0 (T B E 1 4 E)) 1).
Compute ("delete_5/DeletePost"%string, prop_DeletePost (T B E 3 0 (T R E 4 0 E)) 4 4).
Compute ("delete_5/DeleteDelete"%string, prop_DeleteDelete (T B E (-4) 6 (T R E 9 0 E)) 9 (-4)).
Compute ("delete_5/DeleteInsert"%string, prop_DeleteInsert (T B E 0 0 E) 1 1 0).
Compute ("miscolor_insert/InsertValid"%string, prop_InsertValid (T B E 0 0 E) 1 0).
Compute ("miscolor_insert/DeleteInsert"%string, prop_DeleteInsert (T B E 1 0 E) 0 0 0).
Compute ("miscolor_delete/DeleteValid"%string, prop_DeleteValid (T B E 0 0 (T R E 1 1 E)) 2).
Compute ("miscolor_balLeft/DeleteValid"%string, prop_DeleteValid (T B (T B E (-5) 0 E) 0 0 (T R (T B E 2 2 E) 5 6 (T B E 6 1 E))) (-5)).
Compute ("miscolor_balLeft/DeleteDelete"%string, prop_DeleteDelete (T B (T B E (-2) 6 E) (-1) 0 (T R (T B E 0 0 E) 3 0 (T B E 5 8 E))) 5 (-2)).
Compute ("miscolor_balRight/DeleteValid"%string, prop_DeleteValid (T B (T R (T B E (-8) 0 E) (-2) 0 (T B E 0 0 E)) 6 0 (T B E 7 6 E)) 7).
Compute ("miscolor_balRight/DeleteDelete"%string, prop_DeleteDelete (T B (T R (T B E (-9) 1 E) (-8) 0 (T B E 0 0 E)) 3 0 (T B E 6 5 E)) (-9) 6).
Compute ("miscolor_join_1/DeleteValid"%string, prop_DeleteValid (T B (T B (T R (T B E (-12) 2 E) (-6) 0 (T B E (-3) 0 E)) (-2) 0 (T R (T B (T R E 0 0 E) 3 0 E) 4 0 (T B E 5 4 E))) 6 3 (T B (T B E 8 8 E) 9 0 (T B E 10 0 E))) (-2)).
Compute ("miscolor_join_2/DeleteValid"%string, prop_DeleteValid (T B (T B E (-5) 0 (T R E (-4) 1 E)) (-1) 0 (T B (T R E 2 0 E) 4 0 E)) (-1)).
Compute ("miscolor_join_2/DeleteDelete"%string, prop_DeleteDelete (T B (T B E 0 0 E) 1 0 (T R (T B E 2 0 (T R E 3 0 E)) 4 0 (T B E 5 0 E))) 4 0).
Compute ("no_balance_insert_1/InsertValid"%string, prop_InsertValid (T B (T R E 1 1 E) 2 2 E) 0 0).
Compute ("no_balance_insert_1/DeleteInsert"%string, prop_DeleteInsert (T B (T R (T B E (-8) 0 E) 0 0 (T B E 1 0 (T R E 4 2 E))) 5 3 (T B E 7 4 E)) 7 2 0).
Compute ("no_balance_insert_1/InsertDelete"%string, prop_InsertDelete E 0 0 0).
Compute ("no_balance_insert_2/InsertValid"%string, prop_InsertValid (T B E (-1) 0 E) 0 0).
Compute ("no_balance_insert_2/DeleteInsert"%string, prop_DeleteInsert (T B E 0 0 E) 3 3 0).
Compute ("no_balance_insert_2/InsertDelete"%string, prop_InsertDelete E 0 0 0).
