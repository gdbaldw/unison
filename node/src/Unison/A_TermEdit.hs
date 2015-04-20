{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE TemplateHaskell #-}

module Unison.A_TermEdit where

import Control.Applicative
import Control.Monad
import GHC.Generics
import Data.Aeson.TH
import Data.Bytes.Serial
import Unison.A_Eval (Eval)
import Unison.A_Hash (Hash)
import Unison.Note (Noted)
import qualified Data.Set as Set
import qualified Unison.A_Eval as Eval
import qualified Unison.A_Term as Term
import qualified Unison.A_Hash as Hash
import qualified Unison.ABT as ABT

data Action
  = Abstract -- Turn target into function parameter
  | AbstractLet -- Turn target into let bound expression
  | AllowRec -- Turn a let into a let rec
  | EtaReduce -- Eta reduce the target
  | FloatOut -- Float the target binding out one level
  | Inline -- Delete a let binding by inlining its definition into usage sites
  | MergeLet -- Merge a let block into its parent let block
  | Noop -- Do nothing to the target
  | Rename ABT.V -- Rename the target var
  | Step -- Link + beta reduce the target
  | SwapDown -- Swap the target let binding with the subsequent binding
  | SwapUp -- Swap the target let binding with the previous binding
  | WHNF -- Simplify target to weak head normal form
  deriving Generic

-- | Interpret the given 'Action'
interpret :: (Applicative f, Monad f)
          => Eval (Noted f)
          -> (Hash -> Noted f Term.Term)
          -> Term.Path -> Action -> Term.Term -> Noted f (Maybe (Term.Path, Term.Term))
interpret eval link path action t = case action of
  Abstract -> pure $ abstract path t
  AbstractLet -> pure $ abstractLet path t
  AllowRec -> pure $ allowRec path t
  EtaReduce -> pure $ etaReduce path t
  FloatOut -> pure $ floatOut path t
  Inline -> pure $ inline path t
  MergeLet -> pure $ mergeLet path t
  Noop -> pure Nothing
  Rename v -> pure $ rename v path t
  Step -> step eval link path t
  SwapUp -> error "todo - SwapUp"
  SwapDown -> error "todo - SwapDown"
  WHNF -> whnf eval link path t

{- Example:
   f {42} x
   ==>
   f {(v -> v) 42}
-}
abstract :: Term.Path -> Term.Term -> Maybe (Term.Path, Term.Term)
abstract path t = f <$> Term.focus path t where
  f (sub,replace) =
    let sub' = Term.lam (ABT.freshIn' sub "v") (ABT.var' "v")
               `Term.app`
               sub
    in (path,sub')

{- Example:
   f {42} x
   ==>
   f {let v = 42 in v} x
-}
abstractLet :: Term.Path -> Term.Term -> Maybe (Term.Path, Term.Term)
abstractLet path t = f <$> Term.focus path t where
  f (sub,replace) =
    let sub' = Term.let' [(ABT.v' "v", sub)] (ABT.var' "v")
    in (path, sub')

{- Promotes a nonrecurive let to a let rec. Example:
   let x = 1 in x + x
   ==>
   {let rec x = 1 in x + x}
-}
allowRec :: Term.Path -> Term.Term -> Maybe (Term.Path, Term.Term)
allowRec path t = do
  Term.LetNonrec' bs e <- Term.at path t
  t' <- Term.modify (const (Term.letRec bs e)) path t
  pure (path, t')

{- Eta reduce the target. Example:
   { x -> f x }
   ==>
   { f }
-}
etaReduce :: Term.Path -> Term.Term -> Maybe (Term.Path, Term.Term)
etaReduce path t = do
  Term.Lam' v (Term.App' f (ABT.Var' v2)) <- Term.at path t
  guard (v == v2 && not (Set.member v (ABT.freevars f))) -- make sure vars match and `f` doesn't mention `v`
  pure (path, f)

floatOut :: Term.Path -> Term.Term -> Maybe (Term.Path, Term.Term)
floatOut path t = floatLetOut path t <|> floatLamOut path t

{- Moves the target let binding to the parent expression. Example:
   f (let {y = 2} in y*y)
   ==>
   {let y = 2 in f (y*y)}
-}
floatLetOut :: Term.Path -> Term.Term -> Maybe (Term.Path, Term.Term)
floatLetOut path t = do
  parentPath <- Term.parent path >>= Term.parent
  parent <- Term.at parentPath t
  Term.Let' innerBindings e _ _ <- Term.parent path >>= \path -> Term.at path t
  (v, body) <- Term.bindingAt path t
  error "todo: floatLetOut finish me"

{- Example:
   f ({y -> y*y} 2)
   ==>
   {y -> f (y*y)} 2
-}
floatLamOut :: Term.Path -> Term.Term -> Maybe (Term.Path, Term.Term)
floatLamOut _ _ = error "floatLamOut"

{- Delete a let binding by inlining its definition. Fails if binding is recursive. Examples:
   let {x = 1} in x*x
   ==>
   {1*1}

   let
     {x = 1}
     y = 2
   in
     x*x
   ==>
   {let y = 2 in 1*1}
-}
inline :: Term.Path -> Term.Term -> Maybe (Term.Path, Term.Term)
inline path t = do
  (v,body) <- Term.bindingAt path t
  guard (not (Set.member v (ABT.freevars body))) -- can't inline recursive functions
  parentPath <- Term.parent path
  parent <- Term.at parentPath t
  case parent of
    Term.Let' [_] e _ _ -> Just (parentPath, ABT.subst body v e)
    Term.Let' bs e let' _ -> Just (parentPath, ABT.subst body v (let' (filter (\(v',_) -> v' /= v) bs) e))
    _ -> Nothing

{- Example:
   let x = 1 in {let y = 2 in y*y}
   ==>
   {let
     x = 1
     y = 2
   in
     y*y}
-}
mergeLet :: Term.Path -> Term.Term -> Maybe (Term.Path, Term.Term)
mergeLet path t = do
  parentPath <- Term.parent path
  (innerBindings,e,_,_) <- Term.at path t >>= Term.unLet
  (outerBindings,_,let',_) <- Term.at parentPath t >>= Term.unLet
  (,) parentPath <$> Term.modify
    (const $ let' (outerBindings ++ innerBindings) e)
    parentPath
    t

{- Rename the variable at the target, updating all occurrences. -}
rename :: ABT.V -> Term.Path -> Term.Term -> Maybe (Term.Path, Term.Term)
rename v2 path t = do
  ABT.Var' v <- Term.at path t
  guard (v /= v2)
  scope <- Term.boundAt v path t
  (,) scope <$> Term.modify (ABT.subst (ABT.var v2) v) scope t

step :: Applicative f => Eval (Noted f) -> (Hash -> Noted f Term.Term)
     -> Term.Path -> Term.Term -> Noted f (Maybe (Term.Path, Term.Term))
step eval link path t = case Term.focus path t of
  Nothing -> pure Nothing
  Just (sub, replace) -> fmap f (Eval.step eval link sub)
    where f sub = Just (path, replace sub)

whnf :: Applicative f => Eval (Noted f) -> (Hash -> Noted f Term.Term)
     -> Term.Path -> Term.Term -> Noted f (Maybe (Term.Path, Term.Term))
whnf eval link path t = case Term.focus path t of
  Nothing -> pure Nothing
  Just (sub, replace) -> fmap f (Eval.whnf eval link sub)
    where f sub = Just (path, replace sub)

instance Serial Action
deriveJSON defaultOptions ''Action
