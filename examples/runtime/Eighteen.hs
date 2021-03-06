{-# LANGUAGE NoImplicitPrelude #-}

module Eighteen where

import Prelude
       (Bool(..), Maybe(..), (&&), (+), (-), (||), concat, const, drop,
        map, maybe, not, take)

{-# ANN module "HLint: ignore Use foldr" #-}

myId :: a -> a
myId a = a

myPlusPlus :: [a] -> [a] -> [a]
myPlusPlus (a:as) bs = a : myPlusPlus as bs
myPlusPlus [] bs = bs

myReverse :: [a] -> [a]
myReverse [] = []
myReverse (a:as) = as `myPlusPlus` [a]
