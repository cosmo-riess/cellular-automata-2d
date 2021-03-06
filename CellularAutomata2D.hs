module CellularAutomata2D (
    -- * Rules
    Rule(..),
    -- * Torus shaped space
    Torus(..),
    getCell, setCell, setCells, remapIndex,
    getSpaceSize,
    initSpace, initSpaceIO,
    update,
    -- * Space Utils
    forSpace,
    -- * Initializing Spaces
    randomSpace, initSpaceWithCells, initBoolSpaceWithCells, fromMatrix,
    -- * Helper for Rules
    moorIndexDeltas, neumannIndexDeltas, moorIndexDeltasRadiusN,
    makeTotalMoorRule,
    choice, count, countCells, chooseWithPropability,
    makeReversibleRule,
    makeVotingRule, makeVotingMoorRule) where

import System.Random (randomRIO, Random)
import Data.Array (listArray, bounds, (!), Array, (//))
import Control.Arrow
import Control.Monad (forM_)
import Control.Applicative ((<$>))

-------------------------------- General Concepts ------------------------------

-- | A Rule is a function that returns a new cell value for an old state.
-- The new cell value is in the IO Monad so that you can implement nondeterministic
-- (stochastic) automata. The neighborhood is specified by a list of offsets from the cell
-- coordinate.
data Rule a = Rule
    { ruleNeighborhoodDeltas :: [(Int, Int)]
    , ruleFunction :: a -> [a] -> IO a
    }

------------------------------- Torus shaped space -------------------------
-- | A Torus is basically a plane with top and bottom connected as well as left and right connected.
newtype Torus a = Torus { getCells :: Array (Int, Int) a } deriving (Show, Read, Eq)

instance Functor Torus where
    fmap f = Torus . fmap f . getCells

-- | Get a cell at a coordinate in the space.
getCell :: Torus a -> (Int, Int) -> a
getCell space index = getCells space ! remapIndex space index

-- | Set a cell at a coordinate in the space to a new value.
setCell :: Torus a -> (Int, Int) -> a -> Torus a
setCell space index newState = Torus $ getCells space // [(remapIndex space index, newState)]

-- | Set a bunch of cells specified by there coordinate to new values.
setCells :: Torus a -> [((Int, Int), a)] -> Torus a
setCells space cells = Torus $ getCells space // map (first (remapIndex space)) cells

-- | wrap the index around the edges of the space
remapIndex :: Torus a -> (Int, Int) -> (Int, Int)
remapIndex space (row, col) = (row `mod` h, col `mod` w) where (h, w) = getSpaceSize space

-- | Get the dimensions of the space rows * columns
getSpaceSize :: Torus a -> (Int, Int)
getSpaceSize (Torus space) = (maxRow + 1, maxCol + 1)
    where (_, (maxRow, maxCol)) = bounds space

-- | Initializes the space using a given function that takes a coordinate
-- and returns the cell value in the IO Monad (so you can easily e.g. generate
-- a random space configuration).
initSpaceIO :: (Int, Int) -> ((Int, Int) -> IO a) -> IO (Torus a)
initSpaceIO (h, w) initFn = Torus . listArray ((0, 0), (h - 1, w - 1)) <$>
    sequence [initFn (row, col) | row <- [0..h-1], col <- [0..w-1]]

-- | Initializes the space using a pure function which take the coordinate of
-- the cell and returns the cell value
initSpace :: (Int, Int) -> ((Int, Int) -> a) -> Torus a
initSpace (h, w) initFn = Torus $ listArray ((0, 0), (h - 1, w - 1))
    [initFn (row, col) | row <- [0..h-1], col <- [0..w-1]]

-- | Updates a given space by one generation using a given rule.
update :: Rule a -> Torus a -> IO (Torus a)
update rule space = initSpaceIO (getSpaceSize space) updateCell
  where
      updateCell (row, col) = ruleFunction rule self friends
        where
          friends = map (\(dr, dc) -> getCell space (row + dr, col + dc)) (ruleNeighborhoodDeltas rule)
          self = getCell space (row, col)

----------------------------------- Space Utils -------------------------------

-- | Iterates over a given space and calls a given function on the
-- coordinate and value of each cells.
-- This is done in row major order.
forSpace :: Torus a -> ((Int, Int) -> a -> IO ()) -> IO ()
forSpace space fn =
    forM_ [0..spaceHeight - 1] $ \row ->
        forM_ [0..spaceWidth - 1] $ \col ->
            fn (row, col) (getCell space (row, col))
    where (spaceHeight, spaceWidth) = getSpaceSize space

-------------------------------- Initializing Spaces ------------------------------

-- | Initializes a space of a given shape using a list of possible cells.
-- Each cell is randomly chosen from the list.
-- You might want to duplicate elements in the list to adjust the frequency's
-- (probability to be chosen) of the cell values.
randomSpace :: (Int, Int) -> [a] -> IO (Torus a)
randomSpace shape cellStateDist = initSpaceIO shape $ const $ choice cellStateDist

-- | Initializes a space with a default background cell value and a few cells
-- at given coordinates with individual values.
initSpaceWithCells :: (Int, Int) -> a -> [((Int, Int), a)] -> Torus a
initSpaceWithCells shape defaultValue = setCells (initSpace shape (const defaultValue))

-- | Specialized version of initSpaceWithDefault for int spaces with 0 as the background.
initBoolSpaceWithCells :: (Int, Int) -> [(Int, Int)] -> Torus Bool
initBoolSpaceWithCells shape cells = initSpaceWithCells shape False (zip cells (repeat True))

-- | creates a new space from a grid of cells represented as a list of lists
fromMatrix :: [[a]] -> Torus a
fromMatrix mtx = initSpaceWithCells (length mtx, length $ head mtx) undefined cellsOfMatrix
    where cellsOfMatrix = concat $ zipWith makeRow [0..] mtx
          makeRow rowIndex = zipWith (\colIndex cell -> ((rowIndex, colIndex), cell)) [0..]

----------------------------------- Helper for Rules ----------------------------------

-- | Moor neighborhood of radius N
moorIndexDeltasRadiusN :: Int -> [(Int, Int)]
moorIndexDeltasRadiusN n = [(dy, dx) | dx <- [-n..n], dy <- [-n..n], not (dx == 0 && dy == 0)]

-- | The Moor neighborhood, which is used in a lot cellular automata like
-- conway's game of life.
moorIndexDeltas :: [(Int, Int)]
moorIndexDeltas = moorIndexDeltasRadiusN 1

-- | The von Neunmann neighborhood.
neumannIndexDeltas :: [(Int, Int)]
neumannIndexDeltas = [(dy, dx) | dx <- [-1..1], dy <- [-1..1], (dx == 0) /= (dy == 0)]

-- | Creates a life like automata from a list of neighborhood sizes in which
-- a new cell is born and a list of neighborhood sizes where the cell stays
-- alive. e.g. the game of life is makeTotalMoorRule [2,3] [3]
makeTotalMoorRule :: [Int] -> [Int] -> Rule Bool
makeTotalMoorRule getBorn stayAlive = Rule moorIndexDeltas
    (\self neighborhood -> return $ count neighborhood `elem` (if self then stayAlive else getBorn))

-- | Count the number of True (on/alive cells) in the given neighborhood
count :: [Bool] -> Int
count = countCells True

-- | Count the number of cell states in the given neighbprhood
countCells :: Eq a => a -> [a]  -> Int
countCells x = length . filter (== x)

-- | Selects one random element from a list.
-- The list has to be finite.
-- O(n)
choice :: [a] -> IO a
choice xs = (xs !!) `fmap` randomRIO (0, length xs - 1)

-- | Return the first element a with propability p otherwise return b
chooseWithPropability :: Double -> a -> a -> IO a
chooseWithPropability p a b = (\x -> if x < p then a else b) <$> randomRIO (0, 1)

-- | Creates a reversible rule from a non reversible rule by remembering the state and always
-- xoring the new state with the old one.
makeReversibleRule :: Rule Int -> Rule (Int, Int)
makeReversibleRule rule = Rule
    (ruleNeighborhoodDeltas rule)
    (\(c', c) cs -> ruleFunction rule c (map snd cs) >>= \nextC -> return (c, if c' /= nextC then 1 else 0))

-- | Creates a "voting rule", that is a rule for boolean states that only depends on the
-- number of "on" or True cells in the neighborhood and the cell itself
makeVotingRule :: [(Int, Int)] -> (Int -> Bool) -> Rule Bool
makeVotingRule indexDeltas p = Rule indexDeltas $ \self neighborhood -> return $ p (count $ self : neighborhood)

makeVotingMoorRule :: (Int -> Bool) -> Rule Bool
makeVotingMoorRule = makeVotingRule moorIndexDeltas
