----------------------------------------------------------
-- Expressions
--    This is a separate module generated by BNF converter
-----------------------------------------------------------

{- Core/Abs.hs 
module Core.Abs where

-- Haskell module generated by the BNF converter

newtype Ident = Ident String deriving (Eq,Ord,Show)
newtype CaseTk = CaseTk ((Int,Int),String) deriving (Eq,Ord,Show)
newtype DataTk = DataTk ((Int,Int),String) deriving (Eq,Ord,Show)
data Exp =
   ELam Patt Exp
 | ESet
 | EPi Patt Exp Exp
 | ESig Patt Exp Exp
 | EOne
 | Eunit
 | EPair Exp Exp
 | ECon Ident Exp
 | EData DataTk [Summand]
 | ECase CaseTk [Branch]
 | EFst Exp
 | ESnd Exp
 | EApp Exp Exp
 | EVar Ident
 | EVoid
 | EDec Decl Exp
 | EPN
  deriving (Eq,Ord,Show)

data Decl =
   Def Patt Exp Exp
 | Drec Patt Exp Exp
  deriving (Eq,Ord,Show)

data Patt =
   PPair Patt Patt
 | Punit
 | PVar Ident
  deriving (Eq,Ord,Show)

data Summand =
   Summand Ident Exp
  deriving (Eq,Ord,Show)

data Branch =
   Branch Ident Exp
  deriving (Eq,Ord,Show)

-}

-----------------------------------------
-- Main module
-----------------------------------------

{-# OPTIONS_GHC -Wall #-}

module Main where

import Prelude hiding ((*))
import System.Environment
import System.IO.Unsafe

import Core.AbsCore
import Core.PrintCore
import Core.ErrM
import Core.ParCore

-----------------------------------------------------------
-- Values
-----------------------------------------------------------

type Name = Ident

data Val =
     Lam Clos
  |  Pair Val Val
  |  Con Name Val
  |  Unit
  |  Set
  |  Pi  Val Clos
  |  Sig Val Clos
  |  One
  |  Fun  Pos SClos
  |  Data Pos SClos 
  |  Nt Neut
  deriving Show

data Neut = Gen  Int Name
          | App  Neut Nf
          | Fst  Neut
          | Snd  Neut
          | NtFun Pos SClos Neut
  deriving Show

type SClos = ([(Name,Exp)], Rho)
type   Nf  = Val
type TVal  = Val

----------------------------------------
-- Choice of function representations
----------------------------------------

-- Function closures
data Clos = Cl Patt Exp Rho | ClCmp Clos Name deriving Show

-- instantiation of a closure by a value
(*) :: Clos -> Val -> Either String Val
(Cl p e rho) * v = eval e (UpVar rho p v)
(ClCmp f c ) * v = f * Con c v

mkCl :: Patt -> Exp -> Rho -> Clos
mkCl p e rho = Cl p e rho

clCmp :: Clos -> Name -> Clos
clCmp g c  = ClCmp g c


{-
--  Higher order functions

type Clos = Val -> Val
instance Show Clos where show f = "Clos" ++ showVal 0 (Lam f)

(*) :: Clos -> Val -> Val
f * v = f v 

mkCl :: Patt -> Exp -> Rho -> Clos
mkCl p e rho = \v -> eval e (UpVar rho p v)

clCmp :: Clos -> Name -> Clos
clCmp g c = \v -> g * (Con c v)
-}

-------------------------------------
-- Operaions on Values
-------------------------------------

type Pos = ((Int, Int), String)


app :: Val -> Val -> G Val
app (Lam f)             v        = f * v
app (Fun _ (ces, rho)) (Con c v) = do
  evalERho <- eval e rho
  app evalERho v
  where e = head [e' | (c',e') <- ces, c == c']
app (Fun pos s)        (Nt k)    = Right (Nt(NtFun pos s k))
app (Nt k)             m         = Right (Nt(App k m))
app w u = Left ("app " ++ showVal 0 w ++ showVal 0 u)

vfst :: Val -> G Val
vfst (Pair u1 _) = Right u1
vfst (Nt k)      = Right $ Nt (Fst k)
vfst w = Left ("vfst " ++ showVal 0 w)

vsnd :: Val -> G Val
vsnd (Pair _ u2) = Right u2
vsnd (Nt k)      = Right $ Nt (Snd k)
vsnd w = Left ("vsnd " ++ showVal 0 w)

---------------------------------------------
-- Environment
---------------------------------------------

data Rho = RNil | UpVar Rho Patt Val | UpDec Rho Decl deriving Show

getRho :: Rho -> Name -> G Val
getRho (UpVar rho p v) x | x `inPat` p = patProj p x v
                         | otherwise   = getRho rho x
getRho (UpDec rho (Def  p _ e)) x
  | x `inPat` p =
    do
      evalERho <- eval e rho
      patProj p x evalERho
  | otherwise   = getRho rho x
getRho rho0@(UpDec rho (Drec p _ e)) x
  | x `inPat` p =
    do
      evalERho0 <- eval e rho0
      patProj p x evalERho0
  | otherwise   = getRho rho x
getRho RNil _ = error "getRho"

inPat :: Name -> Patt -> Bool
inPat x (PVar y)      = x == y
inPat x (PPair p1 p2) = inPat x p1 || inPat x p2
inPat _ Punit         = False

patProj :: Patt -> Name -> Val -> G Val
patProj (PVar y)      x v
  | x == y       = Right v
patProj (PPair p1 p2) x v
  | x `inPat` p1 =
    do
      vfstV <- vfst v
      patProj p1 x vfstV
  | x `inPat` p2 = 
    do
      vsndV <- vsnd v
      patProj p2 x vsndV
patProj _ _ _ = Left "patProj"

lRho :: Rho -> Int
lRho RNil            = 0
lRho (UpVar rho _ _) = lRho rho + 1
lRho (UpDec rho _  ) = lRho rho


eval :: Exp -> Rho -> G Val
eval e0 rho = case e0 of
    ESet          -> Right (Set)
    EDec d e      -> eval e (UpDec rho d)
    ELam p e      -> Right (Lam $ mkCl p e rho)
    EPi  p a b    ->
      do
        evalERho <- eval a rho
        Right (Pi  evalERho $ mkCl p b rho)
    ESig p a b    ->
      do
        evalARho <- eval a rho
        Right $ Sig evalARho $ mkCl p b rho
    EOne          -> Right (One)
    Eunit         -> Right (Unit)
    EFst e        ->
      do
        evalERho <- eval e rho
        vfst evalERho
    ESnd e        ->
      do
        evalERho <- eval e rho
        vsnd evalERho
    EApp e1 e2    ->
      do
        evalE1Rho <- eval e1 rho
        evalE2Rho <- eval e2 rho
        app evalE1Rho evalE2Rho
    EVar x        -> getRho rho x
    EPair e1 e2   ->
      do
        evalE1Rho <- eval e1 rho
        evalE2Rho <- eval e2 rho
        Right (Pair evalE1Rho evalE2Rho)
    ECon c e1     ->
      do
        evalE1Rho <- eval e1 rho
        Right (Con c evalE1Rho)
    EData (DataTk pos) cas
                  -> Right (Data pos ([(c,a) | Summand c a <- cas], rho))
    ECase (CaseTk pos) ces
                  -> Right (Fun  pos ([(c,e) | Branch  c e <- ces], rho))
    e -> Left $ "eval: should have been desugared\n e = " ++ printTree e

-------------------------------------------
-- Readback functions
-------------------------------------------

eVar :: String -> Exp
eVar = EVar . Ident

rbV :: Int -> Val  -> G Exp -- to do: change to Normal Expression

rbV i v0 = case v0 of
      Lam f      ->
        do
          fGenI <- f * gen i
          rbVSucI <- rbV (i+1) fGenI
          return $ ELam (pat i) rbVSucI
      Pair u v   ->
        do
          valU <- rbV i u
          valV <- rbV i v
          return $ EPair valU valV
      Con  c v   ->
        do
          valV <- rbV i v
          return $ ECon c valV
      Unit       -> return Eunit
      Set        -> return ESet
      Pi  t g    ->
        do
          gGenI <- g * gen i
          valG <- rbV (i+1) gGenI
          valT <- rbV i t
          return $ EPi (pat i) valT valG
      Sig t g    ->
        do
          gGenI <- (g * gen i)
          valG <- (rbV (i+1) gGenI)
          valT <- (rbV i t)
          return $ ESig (pat i) valT valG
      One        -> return EOne
      Fun  pos (_,rho) ->
        do
          valI <- rbRho i rho
          return $ foldr (flip EApp) (eVar $ show pos) valI
      Data pos (_,rho) ->
        do
          valI <- (rbRho i rho)
          return $ foldr (flip EApp) (eVar $ show pos) valI
      Nt k       -> rbN i k
    where pat j = PVar $ Ident $ "G#" ++ show j
          gen j = Nt $ Gen j (Ident "G#")

rbN :: Int -> Neut -> G Exp
rbN i k0 = case k0 of
      Gen j x -> return $ eVar $ printTree x++show j
      App k m ->
        do
          valK <- rbN i k
          valM <- rbV i m
          return $ EApp valK valM
      Fst k   ->
        do
          valK <- rbN i k
          return $ EFst valK
      Snd k   ->
        do
          valK <- rbN i k
          return $ ESnd valK
      NtFun pos (_,rho) k ->
        do
          rbI <- (rbRho i rho)
          rbK <- rbN i k
          return $ foldr (flip EApp) (eVar $ show pos) rbI `EApp` rbK

rbRho :: Int -> Rho -> G [Exp]
rbRho _ RNil = return []
rbRho i (UpVar rho _ v) =
  do
    r1 <- rbV i v
    rs <- rbRho i rho
    return $ r1 : rs
rbRho i (UpDec rho _  ) = rbRho i rho

------------------------------------------------
-- Error monad
------------------------------------------------

type ErrorMessage = String
type G a = Either ErrorMessage a

------------------------------------------------
-- Type environment
------------------------------------------------

type Gamma = [(Name, TVal)]

lookupG :: (Show a, Eq a) => a -> [(a,b)] -> G b
lookupG x xts = case lookup x xts of Just t  -> return t
                                     Nothing -> fail $ "lookupG:" ++ show x

-- Updating type environment   Gamma |- p : t = u => Gamma'
upG :: Gamma -> Patt -> TVal -> Val -> G Gamma
upG gma Punit         _         _ = return gma
upG gma (PVar x)      t         _ = return $ (x,t):gma
upG gma (PPair p1 p2) (Sig t g) v =
  do
    vfstV <- (vfst v)
    gma1 <- upG gma p1 t vfstV
    vsndV <- (vsnd v)
    gVfstV <- (g * vfstV)
    upG gma1 p2 gVfstV vsndV
upG _   p             _         _ = fail $ "upG: p = " ++ printTree p

-------------------------------------------------
-- Type checking rules
-------------------------------------------------

genV :: Rho -> Val
genV rho = Nt(Gen (lRho rho) (Ident "TC#"))

checkD :: Rho -> Gamma -> Decl -> G Gamma
checkT :: Rho -> Gamma -> Exp  -> G ()
check  :: Rho -> Gamma -> Exp  -> TVal -> G ()
checkI :: Rho -> Gamma -> Exp  -> G TVal

checkD rho gma d@(Def  p a e) = do
  debug $ "checking "++ printTree d
  checkT rho gma a
  t <- eval a rho
  check rho gma e t
  evalERho <- eval e rho
  gma1 <- upG gma p t evalERho
  return gma1

checkD rho gma d@(Drec p a e) = do
  debug $ "checking "++ printTree d
  checkT rho gma a
  t <- eval a rho
  let gen = genV rho
  gma1 <- upG gma p t gen
  check (UpVar rho p gen) gma1 e t
  v <- eval e (UpDec rho d)
  gma2 <- upG gma p t v
  return gma2

checkT rho gma e0 =
  case e0 of
    EPi  p a b ->
      do
        checkT rho gma a
        aEval <- (eval a rho)
        gma1 <- upG gma p aEval (genV rho)
        checkT (UpVar rho p (genV rho)) gma1 b
    ESig p a b -> checkT rho gma (EPi p a b)
    ESet       -> return ()
    EOne       -> return ()
    a          -> check rho gma a Set

check rho gma e0 t0 = do
  case (e0, t0) of
    (ELam p e   , Pi  t g )-> do let gen = genV rho
                                 gma1 <- upG gma p t gen
                                 gGen <- g * gen
                                 check (UpVar rho p gen) gma1 e gGen
    (EPair e1 e2, Sig t g )-> do check rho gma e1 t
                                 evalE1 <- eval e1 rho
                                 gEvalE1 <- g * evalE1
                                 check rho gma e2 gEvalE1
    (ECon c e   , Data _ (cas,rho1))-> do a <- lookupG c cas
                                          evalA <- eval a rho1
                                          check rho gma e evalA
    (ECase _ ces, Pi (Data _ (cas, rho1)) g)
      | cs == cs1 ->
        sequence_
          [do
            evalA <- eval a rho1
            check rho gma e (Pi evalA (clCmp g c))
          | (Branch c e, (_,a)) <- zip ces cas
          ]
      | otherwise -> fail "case branches does not match the data type"
      where cs  = [c | Branch c _ <- ces]
            cs1 = [c | (c, _)     <- cas]
    (Eunit      , One)-> return ()
    (EOne       , Set)-> return ()
    (EPi  p a b , Set)-> do check rho gma a Set
                            let gen = genV rho
                            evalA <- eval a rho
                            gma1 <- upG gma p evalA gen
                            check (UpVar rho p gen) gma1 b Set
    (ESig p a b , Set)-> check rho gma (EPi p a b) Set
    (EData _ cas, Set)-> sequence_ [check rho gma a Set | Summand _ a <- cas]
    (EDec d e   , t  )-> do gma1 <- checkD rho gma d
                            check (UpDec rho d) gma1 e t
    (e          , t  )-> do t1 <- checkI rho gma e
                            eqNf (lRho rho) t t1
  where
  eqNf :: Int -> Nf -> Nf -> G ()
  eqNf i m1 m2 =
    do
      e1 <- rbV i m1
      e2 <- rbV i m2
      if e1 == e2
        then return ()
        else fail $ "eqNf: " ++ printTree e1 ++ "=/=" ++ printTree e2

checkI rho gma e0 =
  case e0 of
    EVar x     -> lookupG x gma
    EApp e1 e2 -> do t1 <- checkI rho gma e1
                     (t, g) <- extPiG t1
                     check rho gma e2 t
                     evalE2 <- eval e2 rho
                     g * evalE2
    EFst e     -> fst `fmap` (extSigG =<< checkI rho gma e)
    ESnd e     -> do t <- checkI rho gma e
                     (_, g) <- extSigG t
                     evalE <- eval e rho
                     vfstE <- vfst evalE
                     g * vfstE

    e          -> fail ("checkI: " ++ printTree e)
  where
  extPiG :: TVal -> G (TVal, Clos)
  extPiG (Pi t g) = return (t, g)
  extPiG u        = fail ("extPiG " ++ showVal 0 u)

  extSigG :: TVal -> G (TVal, Clos)
  extSigG (Sig t g) = return (t, g)
  extSigG u         = fail ("extSigG " ++ showVal 0 u)

------------------------------------------------------
-- Main checking routines
------------------------------------------------------

-- The input is checked as an expression of type One.
checkMain :: Exp -> G ()
checkMain e = check RNil [] e One

-- checking a string input
checkStr :: String -> IO()
checkStr s =
  case pExp $ myLexer s of -- parsing using routines generated by BNF converter
    Bad msg -> putStrLn $ "Parse error: " ++ msg
    Ok  e  -> do
      case checkMain e of
        Left  msg' -> putStrLn ("type-checking failed:\n" ++ msg')
        Right _    -> putStrLn ("type-checking succeded.")

-- checking the content of a file.
checkFile :: String -> IO()
checkFile file = checkStr =<< readFile file

-- main routine to execute at a command line.
main :: IO()
main = do args <- getArgs
          case args of [file] -> checkFile file
                       _      -> putStrLn "usage: agdacore FILE"

-----------------------------------------------------
-- For debugging
-----------------------------------------------------
debug :: String -> G ()
debug = \s -> do () <- return $ unsafePerformIO $ putStrLn s; return ()

showVal :: Int -> Val -> String  -- for debug print only
showVal i u = show (rbV i u)
