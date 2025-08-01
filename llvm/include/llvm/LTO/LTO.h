//===-LTO.h - LLVM Link Time Optimizer ------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file declares functions and classes used to support LTO. It is intended
// to be used both by LTO classes as well as by clients (gold-plugin) that
// don't utilize the LTO code generator interfaces.
//
//===----------------------------------------------------------------------===//

#ifndef LLVM_LTO_LTO_H
#define LLVM_LTO_LTO_H

#include "llvm/Support/Compiler.h"
#include <memory>

#include "llvm/ADT/DenseMap.h"
#include "llvm/ADT/MapVector.h"
#include "llvm/Bitcode/BitcodeReader.h"
#include "llvm/IR/ModuleSummaryIndex.h"
#include "llvm/LTO/Config.h"
#include "llvm/Object/IRSymtab.h"
#include "llvm/Support/Caching.h"
#include "llvm/Support/Error.h"
#include "llvm/Support/StringSaver.h"
#include "llvm/Support/ThreadPool.h"
#include "llvm/Support/thread.h"
#include "llvm/Transforms/IPO/FunctionAttrs.h"
#include "llvm/Transforms/IPO/FunctionImport.h"

namespace llvm {

class Error;
class IRMover;
class LLVMContext;
class MemoryBufferRef;
class Module;
class raw_pwrite_stream;
class ToolOutputFile;

/// Resolve linkage for prevailing symbols in the \p Index. Linkage changes
/// recorded in the index and the ThinLTO backends must apply the changes to
/// the module via thinLTOFinalizeInModule.
///
/// This is done for correctness (if value exported, ensure we always
/// emit a copy), and compile-time optimization (allow drop of duplicates).
LLVM_ABI void thinLTOResolvePrevailingInIndex(
    const lto::Config &C, ModuleSummaryIndex &Index,
    function_ref<bool(GlobalValue::GUID, const GlobalValueSummary *)>
        isPrevailing,
    function_ref<void(StringRef, GlobalValue::GUID, GlobalValue::LinkageTypes)>
        recordNewLinkage,
    const DenseSet<GlobalValue::GUID> &GUIDPreservedSymbols);

/// Update the linkages in the given \p Index to mark exported values
/// as external and non-exported values as internal. The ThinLTO backends
/// must apply the changes to the Module via thinLTOInternalizeModule.
LLVM_ABI void thinLTOInternalizeAndPromoteInIndex(
    ModuleSummaryIndex &Index,
    function_ref<bool(StringRef, ValueInfo)> isExported,
    function_ref<bool(GlobalValue::GUID, const GlobalValueSummary *)>
        isPrevailing);

/// Computes a unique hash for the Module considering the current list of
/// export/import and other global analysis results.
LLVM_ABI std::string computeLTOCacheKey(
    const lto::Config &Conf, const ModuleSummaryIndex &Index,
    StringRef ModuleID, const FunctionImporter::ImportMapTy &ImportList,
    const FunctionImporter::ExportSetTy &ExportList,
    const std::map<GlobalValue::GUID, GlobalValue::LinkageTypes> &ResolvedODR,
    const GVSummaryMapTy &DefinedGlobals,
    const DenseSet<GlobalValue::GUID> &CfiFunctionDefs = {},
    const DenseSet<GlobalValue::GUID> &CfiFunctionDecls = {});

/// Recomputes the LTO cache key for a given key with an extra identifier.
LLVM_ABI std::string recomputeLTOCacheKey(const std::string &Key,
                                          StringRef ExtraID);

namespace lto {

LLVM_ABI StringLiteral getThinLTODefaultCPU(const Triple &TheTriple);

/// Given the original \p Path to an output file, replace any path
/// prefix matching \p OldPrefix with \p NewPrefix. Also, create the
/// resulting directory if it does not yet exist.
LLVM_ABI std::string getThinLTOOutputFile(StringRef Path, StringRef OldPrefix,
                                          StringRef NewPrefix);

/// Setup optimization remarks.
LLVM_ABI Expected<std::unique_ptr<ToolOutputFile>> setupLLVMOptimizationRemarks(
    LLVMContext &Context, StringRef RemarksFilename, StringRef RemarksPasses,
    StringRef RemarksFormat, bool RemarksWithHotness,
    std::optional<uint64_t> RemarksHotnessThreshold = 0, int Count = -1);

/// Setups the output file for saving statistics.
LLVM_ABI Expected<std::unique_ptr<ToolOutputFile>>
setupStatsFile(StringRef StatsFilename);

/// Produces a container ordering for optimal multi-threaded processing. Returns
/// ordered indices to elements in the input array.
LLVM_ABI std::vector<int> generateModulesOrdering(ArrayRef<BitcodeModule *> R);

/// Updates MemProf attributes (and metadata) based on whether the index
/// has recorded that we are linking with allocation libraries containing
/// the necessary APIs for downstream transformations.
LLVM_ABI void updateMemProfAttributes(Module &Mod,
                                      const ModuleSummaryIndex &Index);

class LTO;
struct SymbolResolution;

/// An input file. This is a symbol table wrapper that only exposes the
/// information that an LTO client should need in order to do symbol resolution.
class InputFile {
public:
  struct Symbol;

private:
  // FIXME: Remove LTO class friendship once we have bitcode symbol tables.
  friend LTO;
  InputFile() = default;

  std::vector<BitcodeModule> Mods;
  SmallVector<char, 0> Strtab;
  std::vector<Symbol> Symbols;

  // [begin, end) for each module
  std::vector<std::pair<size_t, size_t>> ModuleSymIndices;

  StringRef TargetTriple, SourceFileName, COFFLinkerOpts;
  std::vector<StringRef> DependentLibraries;
  std::vector<std::pair<StringRef, Comdat::SelectionKind>> ComdatTable;

public:
  LLVM_ABI ~InputFile();

  /// Create an InputFile.
  LLVM_ABI static Expected<std::unique_ptr<InputFile>>
  create(MemoryBufferRef Object);

  /// The purpose of this struct is to only expose the symbol information that
  /// an LTO client should need in order to do symbol resolution.
  struct Symbol : irsymtab::Symbol {
    friend LTO;

  public:
    Symbol(const irsymtab::Symbol &S) : irsymtab::Symbol(S) {}

    using irsymtab::Symbol::isUndefined;
    using irsymtab::Symbol::isCommon;
    using irsymtab::Symbol::isWeak;
    using irsymtab::Symbol::isIndirect;
    using irsymtab::Symbol::getName;
    using irsymtab::Symbol::getIRName;
    using irsymtab::Symbol::getVisibility;
    using irsymtab::Symbol::canBeOmittedFromSymbolTable;
    using irsymtab::Symbol::isTLS;
    using irsymtab::Symbol::getComdatIndex;
    using irsymtab::Symbol::getCommonSize;
    using irsymtab::Symbol::getCommonAlignment;
    using irsymtab::Symbol::getCOFFWeakExternalFallback;
    using irsymtab::Symbol::getSectionName;
    using irsymtab::Symbol::isExecutable;
    using irsymtab::Symbol::isUsed;
  };

  /// A range over the symbols in this InputFile.
  ArrayRef<Symbol> symbols() const { return Symbols; }

  /// Returns linker options specified in the input file.
  StringRef getCOFFLinkerOpts() const { return COFFLinkerOpts; }

  /// Returns dependent library specifiers from the input file.
  ArrayRef<StringRef> getDependentLibraries() const { return DependentLibraries; }

  /// Returns the path to the InputFile.
  LLVM_ABI StringRef getName() const;

  /// Returns the input file's target triple.
  StringRef getTargetTriple() const { return TargetTriple; }

  /// Returns the source file path specified at compile time.
  StringRef getSourceFileName() const { return SourceFileName; }

  // Returns a table with all the comdats used by this file.
  ArrayRef<std::pair<StringRef, Comdat::SelectionKind>> getComdatTable() const {
    return ComdatTable;
  }

  // Returns the only BitcodeModule from InputFile.
  LLVM_ABI BitcodeModule &getSingleBitcodeModule();

private:
  ArrayRef<Symbol> module_symbols(unsigned I) const {
    const auto &Indices = ModuleSymIndices[I];
    return {Symbols.data() + Indices.first, Symbols.data() + Indices.second};
  }
};

using IndexWriteCallback = std::function<void(const std::string &)>;

using ImportsFilesContainer = llvm::SmallVector<std::string>;

/// This class defines the interface to the ThinLTO backend.
class ThinBackendProc {
protected:
  const Config &Conf;
  ModuleSummaryIndex &CombinedIndex;
  const DenseMap<StringRef, GVSummaryMapTy> &ModuleToDefinedGVSummaries;
  IndexWriteCallback OnWrite;
  bool ShouldEmitImportsFiles;
  DefaultThreadPool BackendThreadPool;
  std::optional<Error> Err;
  std::mutex ErrMu;

public:
  ThinBackendProc(
      const Config &Conf, ModuleSummaryIndex &CombinedIndex,
      const DenseMap<StringRef, GVSummaryMapTy> &ModuleToDefinedGVSummaries,
      lto::IndexWriteCallback OnWrite, bool ShouldEmitImportsFiles,
      ThreadPoolStrategy ThinLTOParallelism)
      : Conf(Conf), CombinedIndex(CombinedIndex),
        ModuleToDefinedGVSummaries(ModuleToDefinedGVSummaries),
        OnWrite(OnWrite), ShouldEmitImportsFiles(ShouldEmitImportsFiles),
        BackendThreadPool(ThinLTOParallelism) {}

  virtual ~ThinBackendProc() = default;
  virtual void setup(unsigned ThinLTONumTasks, unsigned ThinLTOTaskOffset,
                     Triple Triple) {}
  virtual Error start(
      unsigned Task, BitcodeModule BM,
      const FunctionImporter::ImportMapTy &ImportList,
      const FunctionImporter::ExportSetTy &ExportList,
      const std::map<GlobalValue::GUID, GlobalValue::LinkageTypes> &ResolvedODR,
      MapVector<StringRef, BitcodeModule> &ModuleMap) = 0;
  virtual Error wait() {
    BackendThreadPool.wait();
    if (Err)
      return std::move(*Err);
    return Error::success();
  }
  unsigned getThreadCount() { return BackendThreadPool.getMaxConcurrency(); }
  virtual bool isSensitiveToInputOrder() { return false; }

  // Write sharded indices and (optionally) imports to disk
  LLVM_ABI Error emitFiles(const FunctionImporter::ImportMapTy &ImportList,
                           StringRef ModulePath,
                           const std::string &NewModulePath) const;

  // Write sharded indices to SummaryPath, (optionally) imports to disk, and
  // (optionally) record imports in ImportsFiles.
  LLVM_ABI Error emitFiles(
      const FunctionImporter::ImportMapTy &ImportList, StringRef ModulePath,
      const std::string &NewModulePath, StringRef SummaryPath,
      std::optional<std::reference_wrapper<ImportsFilesContainer>> ImportsFiles)
      const;
};

/// This callable defines the behavior of a ThinLTO backend after the thin-link
/// phase. It accepts a configuration \p C, a combined module summary index
/// \p CombinedIndex, a map of module identifiers to global variable summaries
/// \p ModuleToDefinedGVSummaries, a function to add output streams \p
/// AddStream, and a file cache \p Cache. It returns a unique pointer to a
/// ThinBackendProc, which can be used to launch backends in parallel.
using ThinBackendFunction = std::function<std::unique_ptr<ThinBackendProc>(
    const Config &C, ModuleSummaryIndex &CombinedIndex,
    const DenseMap<StringRef, GVSummaryMapTy> &ModuleToDefinedGVSummaries,
    AddStreamFn AddStream, FileCache Cache)>;

/// This type defines the behavior following the thin-link phase during ThinLTO.
/// It encapsulates a backend function and a strategy for thread pool
/// parallelism. Clients should use one of the provided create*ThinBackend()
/// functions to instantiate a ThinBackend. Parallelism defines the thread pool
/// strategy to be used for processing.
struct ThinBackend {
  ThinBackend(ThinBackendFunction Func, ThreadPoolStrategy Parallelism)
      : Func(std::move(Func)), Parallelism(std::move(Parallelism)) {}
  ThinBackend() = default;

  std::unique_ptr<ThinBackendProc> operator()(
      const Config &Conf, ModuleSummaryIndex &CombinedIndex,
      const DenseMap<StringRef, GVSummaryMapTy> &ModuleToDefinedGVSummaries,
      AddStreamFn AddStream, FileCache Cache) {
    assert(isValid() && "Invalid backend function");
    return Func(Conf, CombinedIndex, ModuleToDefinedGVSummaries,
                std::move(AddStream), std::move(Cache));
  }
  ThreadPoolStrategy getParallelism() const { return Parallelism; }
  bool isValid() const { return static_cast<bool>(Func); }

private:
  ThinBackendFunction Func = nullptr;
  ThreadPoolStrategy Parallelism;
};

/// This ThinBackend runs the individual backend jobs in-process.
/// The default value means to use one job per hardware core (not hyper-thread).
/// OnWrite is callback which receives module identifier and notifies LTO user
/// that index file for the module (and optionally imports file) was created.
/// ShouldEmitIndexFiles being true will write sharded ThinLTO index files
/// to the same path as the input module, with suffix ".thinlto.bc"
/// ShouldEmitImportsFiles is true it also writes a list of imported files to a
/// similar path with ".imports" appended instead.
LLVM_ABI ThinBackend createInProcessThinBackend(
    ThreadPoolStrategy Parallelism, IndexWriteCallback OnWrite = nullptr,
    bool ShouldEmitIndexFiles = false, bool ShouldEmitImportsFiles = false);

/// This ThinBackend generates the index shards and then runs the individual
/// backend jobs via an external process. It takes the same parameters as the
/// InProcessThinBackend; however, these parameters only control the behavior
/// when generating the index files for the modules. Additionally:
/// LinkerOutputFile is a string that should identify this LTO invocation in
/// the context of a wider build. It's used for naming to aid the user in
/// identifying activity related to a specific LTO invocation.
/// Distributor specifies the path to a process to invoke to manage the backend
/// job execution.
/// DistributorArgs specifies a list of arguments to be applied to the
/// distributor.
/// RemoteCompiler specifies the path to a Clang executable to be invoked for
/// the backend jobs.
/// RemoteCompilerArgs specifies a list of arguments to be applied to the
/// backend compilations.
/// SaveTemps is a debugging tool that prevents temporary files created by this
/// backend from being cleaned up.
LLVM_ABI ThinBackend createOutOfProcessThinBackend(
    ThreadPoolStrategy Parallelism, IndexWriteCallback OnWrite,
    bool ShouldEmitIndexFiles, bool ShouldEmitImportsFiles,
    StringRef LinkerOutputFile, StringRef Distributor,
    ArrayRef<StringRef> DistributorArgs, StringRef RemoteCompiler,
    ArrayRef<StringRef> RemoteCompilerArgs, bool SaveTemps);

/// This ThinBackend writes individual module indexes to files, instead of
/// running the individual backend jobs. This backend is for distributed builds
/// where separate processes will invoke the real backends.
///
/// To find the path to write the index to, the backend checks if the path has a
/// prefix of OldPrefix; if so, it replaces that prefix with NewPrefix. It then
/// appends ".thinlto.bc" and writes the index to that path. If
/// ShouldEmitImportsFiles is true it also writes a list of imported files to a
/// similar path with ".imports" appended instead.
/// LinkedObjectsFile is an output stream to write the list of object files for
/// the final ThinLTO linking. Can be nullptr.  If LinkedObjectsFile is not
/// nullptr and NativeObjectPrefix is not empty then it replaces the prefix of
/// the objects with NativeObjectPrefix instead of NewPrefix. OnWrite is
/// callback which receives module identifier and notifies LTO user that index
/// file for the module (and optionally imports file) was created.
LLVM_ABI ThinBackend createWriteIndexesThinBackend(
    ThreadPoolStrategy Parallelism, std::string OldPrefix,
    std::string NewPrefix, std::string NativeObjectPrefix,
    bool ShouldEmitImportsFiles, raw_fd_ostream *LinkedObjectsFile,
    IndexWriteCallback OnWrite);

/// This class implements a resolution-based interface to LLVM's LTO
/// functionality. It supports regular LTO, parallel LTO code generation and
/// ThinLTO. You can use it from a linker in the following way:
/// - Set hooks and code generation options (see lto::Config struct defined in
///   Config.h), and use the lto::Config object to create an lto::LTO object.
/// - Create lto::InputFile objects using lto::InputFile::create(), then use
///   the symbols() function to enumerate its symbols and compute a resolution
///   for each symbol (see SymbolResolution below).
/// - After the linker has visited each input file (and each regular object
///   file) and computed a resolution for each symbol, take each lto::InputFile
///   and pass it and an array of symbol resolutions to the add() function.
/// - Call the getMaxTasks() function to get an upper bound on the number of
///   native object files that LTO may add to the link.
/// - Call the run() function. This function will use the supplied AddStream
///   and Cache functions to add up to getMaxTasks() native object files to
///   the link.
class LTO {
  friend InputFile;

public:
  /// Unified LTO modes
  enum LTOKind {
    /// Any LTO mode without Unified LTO. The default mode.
    LTOK_Default,

    /// Regular LTO, with Unified LTO enabled.
    LTOK_UnifiedRegular,

    /// ThinLTO, with Unified LTO enabled.
    LTOK_UnifiedThin,
  };

  /// Create an LTO object. A default constructed LTO object has a reasonable
  /// production configuration, but you can customize it by passing arguments to
  /// this constructor.
  /// FIXME: We do currently require the DiagHandler field to be set in Conf.
  /// Until that is fixed, a Config argument is required.
  LLVM_ABI LTO(Config Conf, ThinBackend Backend = {},
               unsigned ParallelCodeGenParallelismLevel = 1,
               LTOKind LTOMode = LTOK_Default);
  LLVM_ABI ~LTO();

  /// Add an input file to the LTO link, using the provided symbol resolutions.
  /// The symbol resolutions must appear in the enumeration order given by
  /// InputFile::symbols().
  LLVM_ABI Error add(std::unique_ptr<InputFile> Obj,
                     ArrayRef<SymbolResolution> Res);

  /// Returns an upper bound on the number of tasks that the client may expect.
  /// This may only be called after all IR object files have been added. For a
  /// full description of tasks see LTOBackend.h.
  LLVM_ABI unsigned getMaxTasks() const;

  /// Runs the LTO pipeline. This function calls the supplied AddStream
  /// function to add native object files to the link.
  ///
  /// The Cache parameter is optional. If supplied, it will be used to cache
  /// native object files and add them to the link.
  ///
  /// The client will receive at most one callback (via either AddStream or
  /// Cache) for each task identifier.
  LLVM_ABI Error run(AddStreamFn AddStream, FileCache Cache = {});

  /// Static method that returns a list of libcall symbols that can be generated
  /// by LTO but might not be visible from bitcode symbol table.
  LLVM_ABI static SmallVector<const char *>
  getRuntimeLibcallSymbols(const Triple &TT);

private:
  Config Conf;

  struct RegularLTOState {
    LLVM_ABI RegularLTOState(unsigned ParallelCodeGenParallelismLevel,
                             const Config &Conf);
    struct CommonResolution {
      uint64_t Size = 0;
      Align Alignment;
      /// Record if at least one instance of the common was marked as prevailing
      bool Prevailing = false;
    };
    std::map<std::string, CommonResolution> Commons;

    unsigned ParallelCodeGenParallelismLevel;
    LTOLLVMContext Ctx;
    std::unique_ptr<Module> CombinedModule;
    std::unique_ptr<IRMover> Mover;

    // This stores the information about a regular LTO module that we have added
    // to the link. It will either be linked immediately (for modules without
    // summaries) or after summary-based dead stripping (for modules with
    // summaries).
    struct AddedModule {
      std::unique_ptr<Module> M;
      std::vector<GlobalValue *> Keep;
    };
    std::vector<AddedModule> ModsWithSummaries;
    bool EmptyCombinedModule = true;
  } RegularLTO;

  using ModuleMapType = MapVector<StringRef, BitcodeModule>;

  struct ThinLTOState {
    LLVM_ABI ThinLTOState(ThinBackend Backend);

    ThinBackend Backend;
    ModuleSummaryIndex CombinedIndex;
    // The full set of bitcode modules in input order.
    ModuleMapType ModuleMap;
    // The bitcode modules to compile, if specified by the LTO Config.
    std::optional<ModuleMapType> ModulesToCompile;
    DenseMap<GlobalValue::GUID, StringRef> PrevailingModuleForGUID;
  } ThinLTO;

  // The global resolution for a particular (mangled) symbol name. This is in
  // particular necessary to track whether each symbol can be internalized.
  // Because any input file may introduce a new cross-partition reference, we
  // cannot make any final internalization decisions until all input files have
  // been added and the client has called run(). During run() we apply
  // internalization decisions either directly to the module (for regular LTO)
  // or to the combined index (for ThinLTO).
  struct GlobalResolution {
    /// The unmangled name of the global.
    std::string IRName;

    /// Keep track if the symbol is visible outside of a module with a summary
    /// (i.e. in either a regular object or a regular LTO module without a
    /// summary).
    bool VisibleOutsideSummary = false;

    /// The symbol was exported dynamically, and therefore could be referenced
    /// by a shared library not visible to the linker.
    bool ExportDynamic = false;

    bool UnnamedAddr = true;

    /// True if module contains the prevailing definition.
    bool Prevailing = false;

    /// Returns true if module contains the prevailing definition and symbol is
    /// an IR symbol. For example when module-level inline asm block is used,
    /// symbol can be prevailing in module but have no IR name.
    bool isPrevailingIRSymbol() const { return Prevailing && !IRName.empty(); }

    /// This field keeps track of the partition number of this global. The
    /// regular LTO object is partition 0, while each ThinLTO object has its own
    /// partition number from 1 onwards.
    ///
    /// Any global that is defined or used by more than one partition, or that
    /// is referenced externally, may not be internalized.
    ///
    /// Partitions generally have a one-to-one correspondence with tasks, except
    /// that we use partition 0 for all parallel LTO code generation partitions.
    /// Any partitioning of the combined LTO object is done internally by the
    /// LTO backend.
    unsigned Partition = Unknown;

    /// Special partition numbers.
    enum : unsigned {
      /// A partition number has not yet been assigned to this global.
      Unknown = -1u,

      /// This global is either used by more than one partition or has an
      /// external reference, and therefore cannot be internalized.
      External = -2u,

      /// The RegularLTO partition
      RegularLTO = 0,
    };
  };

  // GlobalResolutionSymbolSaver allocator.
  std::unique_ptr<llvm::BumpPtrAllocator> Alloc;

  // Symbol saver for global resolution map.
  std::unique_ptr<llvm::StringSaver> GlobalResolutionSymbolSaver;

  // Global mapping from mangled symbol names to resolutions.
  // Make this an unique_ptr to guard against accessing after it has been reset
  // (to reduce memory after we're done with it).
  std::unique_ptr<llvm::DenseMap<StringRef, GlobalResolution>>
      GlobalResolutions;

  void releaseGlobalResolutionsMemory();

  void addModuleToGlobalRes(ArrayRef<InputFile::Symbol> Syms,
                            ArrayRef<SymbolResolution> Res, unsigned Partition,
                            bool InSummary);

  // These functions take a range of symbol resolutions and consume the
  // resolutions used by a single input module. Functions return ranges refering
  // to the resolutions for the remaining modules in the InputFile.
  Expected<ArrayRef<SymbolResolution>>
  addModule(InputFile &Input, ArrayRef<SymbolResolution> InputRes,
            unsigned ModI, ArrayRef<SymbolResolution> Res);

  Expected<std::pair<RegularLTOState::AddedModule, ArrayRef<SymbolResolution>>>
  addRegularLTO(InputFile &Input, ArrayRef<SymbolResolution> InputRes,
                BitcodeModule BM, ArrayRef<InputFile::Symbol> Syms,
                ArrayRef<SymbolResolution> Res);
  Error linkRegularLTO(RegularLTOState::AddedModule Mod,
                       bool LivenessFromIndex);

  Expected<ArrayRef<SymbolResolution>>
  addThinLTO(BitcodeModule BM, ArrayRef<InputFile::Symbol> Syms,
             ArrayRef<SymbolResolution> Res);

  Error runRegularLTO(AddStreamFn AddStream);
  Error runThinLTO(AddStreamFn AddStream, FileCache Cache,
                   const DenseSet<GlobalValue::GUID> &GUIDPreservedSymbols);

  Error checkPartiallySplit();

  mutable bool CalledGetMaxTasks = false;

  // LTO mode when using Unified LTO.
  LTOKind LTOMode;

  // Use Optional to distinguish false from not yet initialized.
  std::optional<bool> EnableSplitLTOUnit;

  // Identify symbols exported dynamically, and that therefore could be
  // referenced by a shared library not visible to the linker.
  DenseSet<GlobalValue::GUID> DynamicExportSymbols;

  // Diagnostic optimization remarks file
  std::unique_ptr<ToolOutputFile> DiagnosticOutputFile;
};

/// The resolution for a symbol. The linker must provide a SymbolResolution for
/// each global symbol based on its internal resolution of that symbol.
struct SymbolResolution {
  SymbolResolution()
      : Prevailing(0), FinalDefinitionInLinkageUnit(0), VisibleToRegularObj(0),
        ExportDynamic(0), LinkerRedefined(0) {}

  /// The linker has chosen this definition of the symbol.
  unsigned Prevailing : 1;

  /// The definition of this symbol is unpreemptable at runtime and is known to
  /// be in this linkage unit.
  unsigned FinalDefinitionInLinkageUnit : 1;

  /// The definition of this symbol is visible outside of the LTO unit.
  unsigned VisibleToRegularObj : 1;

  /// The symbol was exported dynamically, and therefore could be referenced
  /// by a shared library not visible to the linker.
  unsigned ExportDynamic : 1;

  /// Linker redefined version of the symbol which appeared in -wrap or -defsym
  /// linker option.
  unsigned LinkerRedefined : 1;
};

} // namespace lto
} // namespace llvm

#endif
