module Unison.Codebase.Editor.Input
  ( Input(..)
  , Event(..)
  , OutputLocation(..)
  , PatchPath
  , BranchId, parseBranchId
  , HashOrHQSplit'
  ) where

import Unison.Prelude

import qualified Unison.Codebase.Branch as Branch
import qualified Unison.Codebase.Branch.Merge as Branch
import qualified Unison.HashQualified          as HQ
import qualified Unison.HashQualified'         as HQ'
import           Unison.Codebase.Path           ( Path' )
import qualified Unison.Codebase.Path          as Path
import qualified Unison.Codebase.Path.Parse as Path
import           Unison.Codebase.PushBehavior (PushBehavior)
import           Unison.Codebase.Editor.RemoteRepo
import           Unison.ShortHash (ShortHash)
import           Unison.Codebase.ShortBranchHash (ShortBranchHash)
import qualified Unison.Codebase.ShortBranchHash as SBH
import           Unison.Codebase.SyncMode       ( SyncMode )
import           Unison.Name                    ( Name )
import           Unison.NameSegment             ( NameSegment )
import qualified Unison.Util.Pretty as P
import           Unison.Codebase.Verbosity

import qualified Data.Text as Text

data Event
  = UnisonFileChanged SourceName Source
  | IncomingRootBranch (Set Branch.Hash)

type Source = Text -- "id x = x\nconst a b = a"
type SourceName = Text -- "foo.u" or "buffer 7"
type PatchPath = Path.Split'
type BranchId = Either ShortBranchHash Path'
type HashOrHQSplit' = Either ShortHash Path.HQSplit'

parseBranchId :: String -> Either String BranchId
parseBranchId ('#':s) = case SBH.fromText (Text.pack s) of
  Nothing -> Left "Invalid hash, expected a base32hex string."
  Just h -> pure $ Left h
parseBranchId s = Right <$> Path.parsePath' s

data Input
  -- names stuff:
    -- directory ops
    -- `Link` must describe a repo and a source path within that repo.
    -- clone w/o merge, error if would clobber
    = ForkLocalBranchI (Either ShortBranchHash Path') Path'
    -- merge first causal into destination
    | MergeLocalBranchI Path' Path' Branch.MergeMode
    | PreviewMergeLocalBranchI Path' Path'
    | DiffNamespaceI Path' Path' -- old new
    | PullRemoteBranchI (Maybe ReadRemoteNamespace) Path' SyncMode Verbosity
    | PushRemoteBranchI (Maybe WriteRemotePath) Path' PushBehavior SyncMode
    | CreatePullRequestI ReadRemoteNamespace ReadRemoteNamespace
    | LoadPullRequestI ReadRemoteNamespace ReadRemoteNamespace Path'
    | ResetRootI (Either ShortBranchHash Path')
    -- todo: Q: Does it make sense to publish to not-the-root of a Github repo?
    --          Does it make sense to fork from not-the-root of a Github repo?
    -- used in Welcome module to give directions to user
    | CreateMessage (P.Pretty P.ColorText)
    -- Change directory. If Nothing is provided, prompt an interactive fuzzy search.
    | SwitchBranchI (Maybe Path')
    | UpI
    | PopBranchI
    -- > names foo
    -- > names foo.bar
    -- > names .foo.bar
    -- > names .foo.bar#asdflkjsdf
    -- > names #sdflkjsdfhsdf
    | NamesI (HQ.HashQualified Name)
    | AliasTermI HashOrHQSplit' Path.Split'
    | AliasTypeI HashOrHQSplit' Path.Split'
    | AliasManyI [Path.HQSplit] Path'
    -- Move = Rename; It's an HQSplit' not an HQSplit', meaning the arg has to have a name.
    | MoveTermI Path.HQSplit' Path.Split'
    | MoveTypeI Path.HQSplit' Path.Split'
    | MoveBranchI (Maybe Path.Split') Path.Split'
    | MovePatchI Path.Split' Path.Split'
    | CopyPatchI Path.Split' Path.Split'
    -- delete = unname
    | DeleteI Path.HQSplit'
    | DeleteTermI Path.HQSplit'
    | DeleteTypeI Path.HQSplit'
    | DeleteBranchI (Maybe Path.Split')
    | DeletePatchI Path.Split'
    -- resolving naming conflicts within `branchpath`
      -- Add the specified name after deleting all others for a given reference
      -- within a given branch.
    | ResolveTermNameI Path.HQSplit'
    | ResolveTypeNameI Path.HQSplit'
  -- edits stuff:
    | LoadI (Maybe FilePath)
    | AddI [HQ'.HashQualified Name]
    | PreviewAddI [HQ'.HashQualified Name]
    | UpdateI (Maybe PatchPath) [HQ'.HashQualified Name]
    | PreviewUpdateI [HQ'.HashQualified Name]
    | TodoI (Maybe PatchPath) Path'
    | PropagatePatchI PatchPath Path'
    | ListEditsI (Maybe PatchPath)
    -- -- create and remove update directives
    | DeprecateTermI PatchPath Path.HQSplit'
    | DeprecateTypeI PatchPath Path.HQSplit'
    | ReplaceI (HQ.HashQualified Name) (HQ.HashQualified Name) (Maybe PatchPath)
    | RemoveTermReplacementI (HQ.HashQualified Name) (Maybe PatchPath)
    | RemoveTypeReplacementI (HQ.HashQualified Name) (Maybe PatchPath)
    | UndoI
    -- First `Maybe Int` is cap on number of results, if any
    -- Second `Maybe Int` is cap on diff elements shown, if any
    | HistoryI (Maybe Int) (Maybe Int) BranchId
    -- execute an IO thunk with args
    | ExecuteI String [String]
    -- execute an IO [Result]
    | IOTestI (HQ.HashQualified Name)
    -- make a standalone binary file
    | MakeStandaloneI String (HQ.HashQualified Name)
    | TestI Bool Bool -- TestI showSuccesses showFailures
    -- metadata
    -- `link metadata definitions` (adds metadata to all of `definitions`)
    | LinkI (HQ.HashQualified Name) [Path.HQSplit']
    -- `unlink metadata definitions` (removes metadata from all of `definitions`)
    | UnlinkI (HQ.HashQualified Name) [Path.HQSplit']
    -- links from <type>
    | LinksI Path.HQSplit' (Maybe String)
    | CreateAuthorI NameSegment {- identifier -} Text {- name -}
      -- Display provided definitions. If list is empty, prompt a fuzzy search.
    | DisplayI OutputLocation [HQ.HashQualified Name]
      -- Display docs for provided terms. If list is empty, prompt a fuzzy search.
    | DocsI [Path.HQSplit']
    -- other
    | SearchByNameI Bool Bool [String] -- SearchByName isVerbose showAll query
    | FindShallowI Path'
    | FindPatchI
      -- Show provided definitions. If list is empty, prompt a fuzzy search.
    | ShowDefinitionI OutputLocation [HQ.HashQualified Name]
    | ShowDefinitionByPrefixI OutputLocation [HQ.HashQualified Name]
    | ShowReflogI
    | UpdateBuiltinsI
    | MergeBuiltinsI
    | MergeIOBuiltinsI
    | ListDependenciesI (HQ.HashQualified Name)
    | ListDependentsI (HQ.HashQualified Name)
    -- | List all external dependencies of a given namespace, or the current namespace if
    -- no path is provided.
    | NamespaceDependenciesI (Maybe Path')
    | DebugNumberedArgsI
    | DebugTypecheckedUnisonFileI
    | DebugDumpNamespacesI
    | DebugDumpNamespaceSimpleI
    | DebugClearWatchI
    | QuitI
    | UiI
    | DocsToHtmlI Path' FilePath
    deriving (Eq, Show)

-- Some commands, like `view`, can dump output to either console or a file.
data OutputLocation
  = ConsoleLocation
  | LatestFileLocation
  | FileLocation FilePath
  -- ClipboardLocation
  deriving (Eq, Show)