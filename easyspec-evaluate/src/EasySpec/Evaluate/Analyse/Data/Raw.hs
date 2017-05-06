{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}

module EasySpec.Evaluate.Analyse.Data.Raw
    ( rawDataRule
    , rawDataRules
    ) where

import Import

import Language.Haskell.Exts.Pretty (prettyPrint)

import Development.Shake
import Development.Shake.Path

import qualified EasySpec.Discover.Types as ES
import qualified EasySpec.OptParse.Types as ES

import EasySpec.Evaluate.Evaluate
import EasySpec.Evaluate.Types

import EasySpec.Evaluate.Analyse.Common
import EasySpec.Evaluate.Analyse.Utils

import EasySpec.Evaluate.Analyse.Data.Files

rawDataRule :: String
rawDataRule = "raw-data"

rawDataRules :: Rules ()
rawDataRules = do
    ghciResource <- newResource "ghci" 1
    es <- examples
    csvFs <- mapM (dataRulesForExample ghciResource) es
    combF <- allDataFile
    combineCSVFiles @EvaluatorCsvLine combF csvFs
    rawDataRule ~> needP [combF]

dataRulesForExample :: Resource -> ES.InputSpec -> Rules (Path Abs File)
dataRulesForExample ghciResource is = do
    names <- namesInSource is
    csvFs <- forM names $ rulesForFileAndName ghciResource is
    combF <- dataFileForExample is
    combineCSVFiles @EvaluatorCsvLine combF csvFs
    pure combF

rulesForFileAndName :: Resource
                    -> ES.InputSpec
                    -> ES.EasyName
                    -> Rules (Path Abs File)
rulesForFileAndName ghciResource is name = do
    csvFs <-
        forM signatureInferenceStrategies $
        rulesForFileNameAndStrat ghciResource is name
    combF <- dataFileForExampleAndName is name
    combineCSVFiles @EvaluatorCsvLine combF csvFs
    pure combF

rulesForFileNameAndStrat
    :: Resource
    -> ES.InputSpec
    -> ES.EasyName
    -> ES.SignatureInferenceStrategy
    -> Rules (Path Abs File)
rulesForFileNameAndStrat ghciResource is name infStrat = do
    csvF <- dataFileFor is name infStrat
    csvF $%> do
        let absFile = ES.inputSpecAbsFile is
        needP [absFile]
        ip <-
            withResource ghciResource 1 $ do
                putLoud $
                    unwords
                        [ "Building data file"
                        , toFilePath csvF
                        , "by running 'easyspec-evaluate' on"
                        , toFilePath absFile
                        , "with focus:"
                        , prettyPrint name
                        , "and signature inference strategy:"
                        , ES.sigInfStratName infStrat
                        ]
                liftIO $ getEvaluationInputPoint is name infStrat
        writeCSV csvF $ evaluationInputPointCsvLines ip
    pure csvF
