{-# LANGUAGE FlexibleContexts #-}

module EasySpec.Discover.CodeUtils where

import Import hiding (Alt)

import Language.Haskell.Exts.Pretty
import Language.Haskell.Exts.Syntax

import EasySpec.Discover.Types

{-# ANN module "HLint: ignore Use const" #-}

{-# ANN module "HLint: ignore Use record patterns" #-}

{-# ANN module "HLint: ignore Avoid lambda" #-}

{-# ANN module "HLint: ignore Collapse lambdas" #-}

getTyVars :: Type t -> [Name t]
getTyVars =
    foldType
        (\_ _ _ -> id)
        (\_ -> (++))
        (\_ _ -> concat)
        (\_ -> id)
        (\_ -> id)
        (\_ -> (++))
        (\_ -> (: []))
        (\_ _ -> [])
        (\_ -> id)
        (\_ v1 _ v2 -> v1 ++ v2)
        (\_ vs _ -> vs)
        (\_ _ -> [])
        (\_ -> (++))
        (\_ _ -> [])
        (\_ _ _ -> id)
        (\_ _ -> [])
        (\_ _ _ -> [])

getPatSymbols :: Pat l -> [QName l]
getPatSymbols =
    foldPat
        (\_ _ -> []) -- Don't count variables
                     -- TODO maybe we should count variables?
        (\_ _ _ -> [])
        (\_ _ _ -> []) -- Don't count n + k patterns
        (\_ b1 qn b2 -> b1 ++ [qn] ++ b2)
        (\_ qn bs -> qn : concat bs)
        (\_ _ bs -> concat bs)
        (\_ bs -> concat bs)
        (\_ b -> b)
        (\_ qn pfs -> qn : concatMap pfpv pfs)
        (\_ _ b -> b) -- Don't count renamings (@)
        (\_ -> [])
        (\_ b -> b)
        (\_ b _ -> b) -- Don't go into types
        (\_ e b -> getExpSymbols e ++ b)
        (\_ rps -> concatMap getRPatSymbols rps)
        (\_ _ _ mb bs -> fromMaybe [] mb ++ concat bs)
        (\_ _ _ mb -> fromMaybe [] mb)
        (\_ _ -> [])
        (\_ b -> b)
        (\_ rpats -> concatMap getRPatSymbols rpats)
        (\_ _ _ -> [])
        (\_ b -> b)
  where
    pfpv :: PatField l -> [QName l]
    pfpv (PFieldPat _ qn p) = qn : getPatSymbols p
    pfpv (PFieldPun _ qn) = [qn]
    pfpv (PFieldWildcard _) = []

getRPatSymbols :: RPat l -> [QName l]
getRPatSymbols = undefined

getQNameSymbols :: QName l -> [Name l]
getQNameSymbols (Qual _ _ n) = [n]
getQNameSymbols (UnQual _ n) = [n]
getQNameSymbols (Special l sc) -- This is kind-of cheating but I'll allow it here.
 = [Ident l $ prettyPrintOneLine sc]

getQOpSymbols :: QOp l -> [QName l]
getQOpSymbols (QVarOp _ _) = [] -- Don't count variables, TODO see above TODO
getQOpSymbols (QConOp _ qn) = [qn]

getBindsSymbols :: Binds l -> [QName l]
getBindsSymbols (BDecls _ ds) = concatMap getDeclSymbols ds
getBindsSymbols (IPBinds _ ipbs) =
    concat [getExpSymbols e | IPBind _ _ e <- ipbs]

getDeclSymbols :: Decl l -> [QName l]
getDeclSymbols d =
    case d of
        FunBind _ ms -> concatMap getMatchSymbols ms
        PatBind _ p1 rhs mbs ->
            getPatSymbols p1 ++
            getRhsSymbols rhs ++ fromMaybe [] (getBindsSymbols <$> mbs)
        PatSyn _ p1 p2 _ -> getPatSymbols p1 ++ getPatSymbols p2 -- what about patSynDirection?
        _ -> []

getMatchSymbols :: Match l -> [QName l]
getMatchSymbols (Match _ _ ps rhs mbs) -- TODO do something with the LHS?
 =
    concatMap getPatSymbols ps ++
    getRhsSymbols rhs ++ fromMaybe [] (getBindsSymbols <$> mbs)
getMatchSymbols (InfixMatch _ p1 _ ps rhs mbs) -- TODO do something with the LHS?
 =
    getPatSymbols p1 ++
    concatMap getPatSymbols ps ++
    getRhsSymbols rhs ++ fromMaybe [] (getBindsSymbols <$> mbs)

getRhsSymbols :: Rhs l -> [QName l]
getRhsSymbols (UnGuardedRhs _ e) = getExpSymbols e
getRhsSymbols (GuardedRhss _ grhss) = concatMap getGuardedRhsSymbols grhss

getGuardedRhsSymbols :: GuardedRhs l -> [QName l]
getGuardedRhsSymbols (GuardedRhs _ stmts e) =
    concatMap getStmtSymbols stmts ++ getExpSymbols e

getAltSymbols :: Alt l -> [QName l]
getAltSymbols (Alt _ p rhs mbs) =
    getPatSymbols p ++
    getRhsSymbols rhs ++ fromMaybe [] (getBindsSymbols <$> mbs)

getStmtSymbols :: Stmt l -> [QName l]
getStmtSymbols (Generator _ p e) = getPatSymbols p ++ getExpSymbols e
getStmtSymbols (Qualifier _ e) = getExpSymbols e
getStmtSymbols (LetStmt _ bs) = getBindsSymbols bs
getStmtSymbols (RecStmt _ stmts) = concatMap getStmtSymbols stmts

getFieldUpdateSymbols :: FieldUpdate l -> [QName l]
getFieldUpdateSymbols = undefined

getQualStmtSymbols :: QualStmt l -> [QName l]
getQualStmtSymbols = undefined

getExpSymbols :: Exp l -> [QName l]
getExpSymbols =
    foldExp
        (\_ _ -> []) -- Don't count variables, TODO see above TODO
        (\_ _ -> [])
        (\_ _ -> []) -- Don't count variables see above
        (\_ qn -> [qn])
        (\_ _ -> [])
        (\_ b1 qo b2 -> b1 ++ getQOpSymbols qo ++ b2)
        (\_ -> (++))
        (\_ -> id)
        (\_ ps b -> concatMap getPatSymbols ps ++ b)
        (\_ bs b -> getBindsSymbols bs ++ b)
        (\_ b1 b2 b3 -> b1 ++ b2 ++ b3)
        (\_ grhss -> concatMap getGuardedRhsSymbols grhss)
        (\_ b as -> b ++ concatMap getAltSymbols as)
        (\_ stmts -> concatMap getStmtSymbols stmts)
        (\_ stmts -> concatMap getStmtSymbols stmts)
        (\_ _ bs -> concat bs)
        (\_ _ mbs -> concat $ catMaybes mbs)
        (\_ bs -> concat bs)
        (\_ bs -> concat bs)
        (\_ b -> b)
        (\_ b qo -> b ++ getQOpSymbols qo)
        (\_ qo b -> getQOpSymbols qo ++ b)
        (\_ qn fus -> qn : concatMap getFieldUpdateSymbols fus)
        (\_ b fus -> b ++ concatMap getFieldUpdateSymbols fus)
        (\_ b -> b)
        (\_ -> (++))
        (\_ -> (++))
        (\_ b1 b2 b3 -> b1 ++ b2 ++ b3)
        (\_ -> (++))
        (\_ b1 b2 b3 -> b1 ++ b2 ++ b3)
        (\_ b qstms -> b ++ concatMap getQualStmtSymbols qstms)
        (\_ b qstmss -> b ++ concatMap (concatMap getQualStmtSymbols) qstmss)
        (\_ b qstmss -> b ++ concatMap (concatMap getQualStmtSymbols) qstmss)
        (\_ b _ -> b) -- Don't count type symbols
        (\_ _ -> [])
        (\_ _ -> [])
        (\_ _ -> [])
        (\_ _ -> [])
        (\_ _ _ -> [])
        (\_ _ -> []) -- Don't count type symbols
        (\_ _ _ mb bs -> fromMaybe [] mb ++ concat bs)
        (\_ _ _ mb -> fromMaybe [] mb)
        (\_ _ -> [])
        (\_ b -> b)
        (\_ bs -> concat bs)
        (\_ _ b -> b)
        (\_ _ b -> b)
        (\_ _ _ _ b -> b)
        (\_ p b -> getPatSymbols p ++ b)
        (\_ -> (++))
        (\_ -> (++))
        (\_ -> (++))
        (\_ -> (++))
        (\_ as -> concatMap getAltSymbols as)
        (\_ -> [])

foldPat ::
       (l -> Name l -> b)
    -> (l -> Sign l -> Literal l -> b)
    -> (l -> Name l -> Integer -> b)
    -> (l -> b -> QName l -> b -> b)
    -> (l -> QName l -> [b] -> b)
    -> (l -> Boxed -> [b] -> b)
    -> (l -> [b] -> b)
    -> (l -> b -> b)
    -> (l -> QName l -> [PatField l] -> b)
    -> (l -> Name l -> b -> b)
    -> (l -> b)
    -> (l -> b -> b)
    -> (l -> b -> Type l -> b)
    -> (l -> Exp l -> b -> b)
    -> (l -> [RPat l] -> b)
    -> (l -> XName l -> [PXAttr l] -> Maybe b -> [b] -> b)
    -> (l -> XName l -> [PXAttr l] -> Maybe b -> b)
    -> (l -> String -> b)
    -> (l -> b -> b)
    -> (l -> [RPat l] -> b)
    -> (l -> String -> String -> b)
    -> (l -> b -> b)
    -> Pat l
    -> b
foldPat f01 f02 f03 f04 f05 f06 f07 f08 f09 f10 f11 f12 f13 f14 f15 f16 f17 f18 f19 f20 f21 f22 =
    go
  where
    go (PVar l n) = f01 l n
    go (PLit l sn lt) = f02 l sn lt
    go (PNPlusK l n int) = f03 l n int
    go (PInfixApp l b1 qn b2) = f04 l (go b1) qn (go b2)
    go (PApp l qn bs) = f05 l qn (map go bs)
    go (PTuple l bxd bs) = f06 l bxd (map go bs)
    go (PList l bs) = f07 l (map go bs)
    go (PParen l b) = f08 l (go b)
    go (PRec l qn patfs) = f09 l qn patfs
    go (PAsPat l n b) = f10 l n (go b)
    go (PWildCard l) = f11 l
    go (PIrrPat l b) = f12 l (go b)
    go (PatTypeSig l b t) = f13 l (go b) t
    go (PViewPat l e b) = f14 l e (go b)
    go (PRPat l rpats) = f15 l rpats
    go (PXTag l xn pxattrs mb bs) = f16 l xn pxattrs (go <$> mb) (map go bs)
    go (PXETag l xn pxattrs mb) = f17 l xn pxattrs (go <$> mb)
    go (PXPcdata l s) = f18 l s
    go (PXPatTag l b) = f19 l (go b)
    go (PXRPats l rpats) = f20 l rpats
    go (PQuasiQuote l s1 s2) = f21 l s1 s2
    go (PBangPat l b) = f22 l (go b)

foldRPatVars :: RPat l -> b
foldRPatVars = undefined

foldType ::
       (l -> Maybe [TyVarBind l] -> Maybe (Context l) -> b -> b)
    -> (l -> b -> b -> b)
    -> (l -> Boxed -> [b] -> b)
    -> (l -> b -> b)
    -> (l -> b -> b)
    -> (l -> b -> b -> b)
    -> (l -> Name l -> b)
    -> (l -> QName l -> b)
    -> (l -> b -> b)
    -> (l -> b -> QName l -> b -> b)
    -> (l -> b -> Kind l -> b)
    -> (l -> Promoted l -> b)
    -> (l -> b -> b -> b)
    -> (l -> Splice l -> b)
    -> (l -> BangType l -> Unpackedness l -> b -> b)
    -> (l -> Maybe (Name l) -> b)
    -> (l -> String -> String -> b)
    -> Type l
    -> b
foldType ffa ff ft fl fpa fa fv fc fp fi fk fpr fe fspl fbng fwc fqq = go
  where
    go (TyForall l mtvbs btc t) = ffa l mtvbs btc (go t)
    go (TyFun l t1 t2) = ff l (go t1) (go t2)
    go (TyTuple l b ts) = ft l b (map go ts)
    go (TyList l lt) = fl l (go lt)
    go (TyParArray l lt) = fpa l (go lt)
    go (TyApp l t1 t2) = fa l (go t1) (go t2)
    go (TyVar l n) = fv l n
    go (TyCon l qn) = fc l qn
    go (TyParen l t) = fp l (go t)
    go (TyInfix l t1 qn t2) = fi l (go t1) qn (go t2)
    go (TyKind l t k) = fk l (go t) k
    go (TyPromoted l p) = fpr l p
    go (TyEquals l t1 t2) = fe l (go t1) (go t2)
    go (TySplice l spl) = fspl l spl
    go (TyBang l bt up t) = fbng l bt up (go t)
    go (TyWildCard l mn) = fwc l mn
    go (TyQuasiQuote l s1 s2) = fqq l s1 s2

mentionsEq :: EasyQName -> EasyEq -> Bool
mentionsEq n (EasyEq e1 e2) = mentions n e1 || mentions n e2

mentions :: Eq l => QName l -> Exp l -> Bool
mentions n e = occurrences n e > 0

occurrencesEq :: EasyQName -> EasyEq -> Int
occurrencesEq n (EasyEq e1 e2) = occurrences n e1 + occurrences n e2

occurrences :: Eq l => QName l -> Exp l -> Int
occurrences n =
    foldExp
        (\_ qn -> q qn)
        (\_ _ -> 0)
        (\_ _ -> 0)
        (\_ qn -> q qn)
        (\_ _ -> 0)
        (\_ b1 _ b2 -> b1 + b2)
        (\_ b1 b2 -> b1 + b2)
        (\_ b -> b)
        (\_ _ b -> b)
        (\_ _ b -> b)
        (\_ b1 b2 b3 -> b1 + b2 + b3)
        (\_ _ -> 0)
        (\_ b _ -> b)
        (\_ _ -> 0)
        (\_ _ -> 0)
        (\_ _ bs -> sum bs)
        (\_ _ mbs -> sum $ catMaybes mbs)
        (\_ bs -> sum bs)
        (\_ bs -> sum bs)
        (\_ b -> b)
        (\_ b _ -> b)
        (\_ _ b -> b)
        (\_ qn _ -> q qn)
        (\_ b _ -> b)
        (\_ b -> b)
        (\_ b1 b2 -> b1 + b2)
        (\_ b1 b2 -> b1 + b2)
        (\_ b1 b2 b3 -> b1 + b2 + b3)
        (\_ b1 b2 -> b1 + b2)
        (\_ b1 b2 b3 -> b1 + b2 + b3)
        (\_ b _ -> b)
        (\_ b _ -> b)
        (\_ b _ -> b)
        (\_ b _ -> b)
        (\_ qn -> q qn)
        (\_ qn -> q qn)
        (\_ _ -> 0)
        (\_ _ -> 0)
        (\_ _ _ -> 0)
        (\_ _ -> 0)
        (\_ _ _ mb bs -> fromMaybe 0 mb + sum bs)
        (\_ _ _ mb -> fromMaybe 0 mb)
        (\_ _ -> 0)
        (\_ b -> b)
        (\_ bs -> sum bs)
        (\_ _ b -> b)
        (\_ _ b -> b)
        (\_ _ _ _ b -> b)
        (\_ _ b -> b)
        (\_ b1 b2 -> b1 + b2)
        (\_ b1 b2 -> b1 + b2)
        (\_ b1 b2 -> b1 + b2)
        (\_ b1 b2 -> b1 + b2)
        (\_ _ -> 0)
        (\_ -> 0)
  where
    q qn =
        if qn == n
            then 1
            else 0

foldExp ::
       (l -> QName l -> b)
    -> (l -> String -> b)
    -> (l -> IPName l -> b)
    -> (l -> QName l -> b)
    -> (l -> Literal l -> b)
    -> (l -> b -> QOp l -> b -> b)
    -> (l -> b -> b -> b)
    -> (l -> b -> b)
    -> (l -> [Pat l] -> b -> b)
    -> (l -> Binds l -> b -> b)
    -> (l -> b -> b -> b -> b)
    -> (l -> [GuardedRhs l] -> b)
    -> (l -> b -> [Alt l] -> b)
    -> (l -> [Stmt l] -> b)
    -> (l -> [Stmt l] -> b)
    -> (l -> Boxed -> [b] -> b)
    -> (l -> Boxed -> [Maybe b] -> b)
    -> (l -> [b] -> b)
    -> (l -> [b] -> b)
    -> (l -> b -> b)
    -> (l -> b -> QOp l -> b)
    -> (l -> QOp l -> b -> b)
    -> (l -> QName l -> [FieldUpdate l] -> b)
    -> (l -> b -> [FieldUpdate l] -> b)
    -> (l -> b -> b)
    -> (l -> b -> b -> b)
    -> (l -> b -> b -> b)
    -> (l -> b -> b -> b -> b)
    -> (l -> b -> b -> b)
    -> (l -> b -> b -> b -> b)
    -> (l -> b -> [QualStmt l] -> b)
    -> (l -> b -> [[QualStmt l]] -> b)
    -> (l -> b -> [[QualStmt l]] -> b)
    -> (l -> b -> Type l -> b)
    -> (l -> QName l -> b)
    -> (l -> QName l -> b)
    -> (l -> Bracket l -> b)
    -> (l -> Splice l -> b)
    -> (l -> String -> String -> b)
    -> (l -> Type l -> b)
    -> (l -> XName l -> [XAttr l] -> Maybe b -> [b] -> b)
    -> (l -> XName l -> [XAttr l] -> Maybe b -> b)
    -> (l -> String -> b)
    -> (l -> b -> b)
    -> (l -> [b] -> b)
    -> (l -> String -> b -> b)
    -> (l -> String -> b -> b)
    -> (l -> String -> (Int, Int) -> (Int, Int) -> b -> b)
    -> (l -> Pat l -> b -> b)
    -> (l -> b -> b -> b)
    -> (l -> b -> b -> b)
    -> (l -> b -> b -> b)
    -> (l -> b -> b -> b)
    -> (l -> [Alt l] -> b)
    -> (l -> b)
    -> Exp l
    -> b
foldExp ff1 ff2 ff3 ff4 ff5 ff6 ff7 ff8 ff9 ff10 ff11 ff12 ff13 ff14 ff15 ff16 ff17 ff18 ff19 ff20 ff21 ff22 ff23 ff24 ff25 ff26 ff27 ff28 ff29 ff30 ff31 ff32 ff33 ff34 ff35 ff36 ff37 ff38 ff39 ff40 ff41 ff42 ff43 ff44 ff45 ff46 ff47 ff48 ff49 ff50 ff51 ff52 ff53 ff54 ff55 =
    go
  where
    go (Var l qn) = ff1 l qn
    go (OverloadedLabel l s) = ff2 l s
    go (IPVar l ipn) = ff3 l ipn
    go (Con l qn) = ff4 l qn
    go (Lit l lit) = ff5 l lit
    go (InfixApp l b1 qop b2) = ff6 l (go b1) qop (go b2)
    go (App l b1 b2) = ff7 l (go b1) (go b2)
    go (NegApp l b) = ff8 l (go b)
    go (Lambda l pats b) = ff9 l pats (go b)
    go (Let l bnds b) = ff10 l bnds (go b)
    go (If l b1 b2 b3) = ff11 l (go b1) (go b2) (go b3)
    go (MultiIf l grhs) = ff12 l grhs
    go (Case l b as) = ff13 l (go b) as
    go (Do l stmts) = ff14 l stmts
    go (MDo l stmts) = ff15 l stmts
    go (Tuple l bd bs) = ff16 l bd (map go bs)
    go (TupleSection l bxd mbs) = ff17 l bxd (map (fmap go) mbs)
    go (List l bs) = ff18 l (map go bs)
    go (ParArray l bs) = ff19 l (map go bs)
    go (Paren l b) = ff20 l (go b)
    go (LeftSection l b qop) = ff21 l (go b) qop
    go (RightSection l qop b) = ff22 l qop (go b)
    go (RecConstr l qn fos) = ff23 l qn fos
    go (RecUpdate l b fos) = ff24 l (go b) fos
    go (EnumFrom l b) = ff25 l (go b)
    go (EnumFromTo l b1 b2) = ff26 l (go b1) (go b2)
    go (EnumFromThen l b1 b2) = ff27 l (go b1) (go b2)
    go (EnumFromThenTo l b1 b2 b3) = ff28 l (go b1) (go b2) (go b3)
    go (ParArrayFromTo l b1 b2) = ff29 l (go b1) (go b2)
    go (ParArrayFromThenTo l b1 b2 b3) = ff30 l (go b1) (go b2) (go b3)
    go (ListComp l b qstms) = ff31 l (go b) qstms
    go (ParComp l b qstmss) = ff32 l (go b) qstmss
    go (ParArrayComp l b qstmss) = ff33 l (go b) qstmss
    go (ExpTypeSig l b ts) = ff34 l (go b) ts
    go (VarQuote l qn) = ff35 l qn
    go (TypQuote l qn) = ff36 l qn
    go (BracketExp l braq) = ff37 l braq
    go (SpliceExp l splice) = ff38 l splice
    go (QuasiQuote l s s2) = ff39 l s s2
    go (TypeApp l t) = ff40 l t
    go (XTag l xnam xas mb bs) = ff41 l xnam xas (go <$> mb) (map go bs)
    go (XETag l xnam xas mb) = ff42 l xnam xas (go <$> mb)
    go (XPcdata l s) = ff43 l s
    go (XExpTag l b) = ff44 l (go b)
    go (XChildTag l bs) = ff45 l (map go bs)
    go (CorePragma l s b) = ff46 l s (go b)
    go (SCCPragma l s b) = ff47 l s (go b)
    go (GenPragma l s t1 t2 b) = ff48 l s t1 t2 (go b)
    go (Proc l pat b) = ff49 l pat (go b)
    go (LeftArrApp l b1 b2) = ff50 l (go b1) (go b2)
    go (RightArrApp l b1 b2) = ff51 l (go b1) (go b2)
    go (LeftArrHighApp l b1 b2) = ff52 l (go b1) (go b2)
    go (RightArrHighApp l b1 b2) = ff53 l (go b1) (go b2)
    go (LCase l as) = ff54 l as
    go (ExprHole l) = ff55 l

prettyPrintOneLine :: Pretty a => a -> String
prettyPrintOneLine =
    prettyPrintStyleMode (style {mode = OneLineMode}) defaultMode
