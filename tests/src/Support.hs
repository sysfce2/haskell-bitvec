{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE FlexibleContexts    #-}
{-# LANGUAGE RankNTypes          #-}
module Support where

import Debug.Trace
import Control.Applicative
import Control.Monad.ST
import Data.Bit
import Data.Bits
import Data.Word
import qualified Data.Vector.Generic         as V
import qualified Data.Vector.Generic.Mutable as M
import qualified Data.Vector.Generic.New     as N
import qualified Data.Vector.Unboxed         as U
import Data.Vector.Unboxed.Bit (wordSize)
import Test.QuickCheck

instance Arbitrary Bit where
    arbitrary = fromBool <$> arbitrary
    shrink = fmap fromBool . shrink . toBool

instance (Arbitrary a, U.Unbox a) => Arbitrary (U.Vector a) where
    arbitrary = V.new <$> arbitrary

instance (Show (v a), V.Vector v a) => Show (N.New v a) where
    showsPrec p = showsPrec p . V.new

newFromList :: forall a v. V.Vector v a => [a] -> N.New v a
newFromList xs = N.create (V.unsafeThaw (V.fromList xs :: v a))

-- this instance is designed to make sure that the arbitrary vectors we work with are not all nicely aligned; we need to deal with cases where the vector is a weird slice of some other vector.
instance (V.Vector v a, Arbitrary a) => Arbitrary (N.New v a) where
    arbitrary = frequency
        [ (10, newFromList <$> arbitrary) 
        , (1,  N.drop <$> arbitrary <*> arbitrary)
        , (1,  N.take <$> arbitrary <*> arbitrary)
        , (1,  slice <$> arbitrary <*> arbitrary <*> arbitrary)
        ]
        where slice s n = N.apply $ \v ->
                 let (s', n') = trimSlice s n (M.length v)
                  in M.slice s' n' v

trimSlice s n l = (s', n')
    where
         s' | l == 0    = 0
            | otherwise = s `mod` l
         n' | s' == 0   = 0
            | otherwise = n `mod` (l - s')

sliceList s n = take n . drop s

readWordL :: [Bit] -> Int -> Word
readWordL xs 0 = loop 0 0 xs
    where
        loop _ w [] = w
        loop i w (x:xs)
            | i >= wordSize = w
            | otherwise     = loop (i+1) (if toBool x then setBit w i else w) xs
readWordL xs n = readWordL (drop n xs) 0

writeWordL :: [Bit] -> Int -> Word -> [Bit]
writeWordL xs 0 w = zipWith const ([ fromBool (testBit w i) | i <- [0 .. wordSize - 1] ]) xs ++ post
    where (pre, post) = splitAt wordSize xs
writeWordL xs n w = pre ++ writeWordL post 0 w
    where (pre, post) = splitAt n xs

prop_writeWordL_preserves_length xs (NonNegative n) w =
    length (writeWordL xs n w) == length xs

prop_writeWordL_preserves_prefix xs (NonNegative n) w =
    take n (writeWordL xs n w) == take n xs

prop_writeWordL_preserves_suffix xs (NonNegative n) w =
    drop (n + wordSize) (writeWordL xs n w) == drop (n + wordSize) xs

prop_writeWordL_readWordL xs n w =
    writeWordL xs n (readWordL xs n) == xs

-- the opposite is more work to state, but these tests together with the simplicity of the definitions makes me reasonably confident in these as a reference implementation.

withNonEmptyMVec :: Eq t =>
       (U.Vector Bit -> t)
    -> (forall s. U.MVector s Bit -> ST s t) 
    -> Property
withNonEmptyMVec f g = forAll arbitrary $ \xs ->
     let xs' = V.new xs 
      in not (U.null xs') ==> f xs' == runST (N.run xs >>= g)
