//===--- Opcodes.td - Opcode defitions for the constexpr VM -----*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// Helper file used to generate opcodes, the interpreter and the disassembler.
//
//===----------------------------------------------------------------------===//


//===----------------------------------------------------------------------===//
// Types evaluated by the interpreter.
//===----------------------------------------------------------------------===//

class Type;
def Bool : Type;
def Sint8 : Type;
def Uint8 : Type;
def Sint16 : Type;
def Uint16 : Type;
def Sint32 : Type;
def Uint32 : Type;
def Sint64 : Type;
def Uint64 : Type;
def IntAP : Type;
def IntAPS : Type;
def Float : Type;
def Ptr : Type;
def MemberPtr : Type;
def FixedPoint : Type;

//===----------------------------------------------------------------------===//
// Types transferred to the interpreter.
//===----------------------------------------------------------------------===//

class ArgType { string Name = ?; bit AsRef = false; }
def ArgSint8 : ArgType { let Name = "int8_t"; }
def ArgUint8 : ArgType { let Name = "uint8_t"; }
def ArgSint16 : ArgType { let Name = "int16_t"; }
def ArgUint16 : ArgType { let Name = "uint16_t"; }
def ArgSint32 : ArgType { let Name = "int32_t"; }
def ArgUint32 : ArgType { let Name = "uint32_t"; }
def ArgSint64 : ArgType { let Name = "int64_t"; }
def ArgUint64 : ArgType { let Name = "uint64_t"; }
def ArgIntAP : ArgType { let Name = "IntegralAP<false>"; let AsRef = true; }
def ArgIntAPS : ArgType { let Name = "IntegralAP<true>"; let AsRef = true; }
def ArgFloat : ArgType { let Name = "Floating"; let AsRef = true; }

def ArgBool : ArgType { let Name = "bool"; }
def ArgFixedPoint : ArgType { let Name = "FixedPoint"; let AsRef = true; }

def ArgFunction : ArgType { let Name = "const Function *"; }
def ArgRecordDecl : ArgType { let Name = "const RecordDecl *"; }
def ArgRecordField : ArgType { let Name = "const Record::Field *"; }
def ArgFltSemantics : ArgType { let Name = "const llvm::fltSemantics *"; }
def ArgRoundingMode : ArgType { let Name = "llvm::RoundingMode"; }
def ArgLETD: ArgType { let Name = "const LifetimeExtendedTemporaryDecl *"; }
def ArgCastKind : ArgType { let Name = "interp::CastKind"; }
def ArgCallExpr : ArgType { let Name = "const CallExpr *"; }
def ArgExpr : ArgType { let Name = "const Expr *"; }
def ArgOffsetOfExpr : ArgType { let Name = "const OffsetOfExpr *"; }
def ArgDeclRef : ArgType { let Name = "const DeclRefExpr *"; }
def ArgCCI : ArgType { let Name = "const ComparisonCategoryInfo *"; }
def ArgValueDecl : ArgType { let Name = "const ValueDecl*"; }
def ArgVarDecl : ArgType { let Name = "const VarDecl*"; }
def ArgDesc : ArgType { let Name = "const Descriptor *"; }
def ArgPrimType : ArgType { let Name = "PrimType"; }
def ArgEnumDecl : ArgType { let Name = "const EnumDecl *"; }
def ArgTypePtr : ArgType { let Name = "const Type *"; }

//===----------------------------------------------------------------------===//
// Classes of types instructions operate on.
//===----------------------------------------------------------------------===//

class TypeClass {
  list<Type> Types;
}

def IntegerTypeClass : TypeClass {
  let Types = [Sint8, Uint8, Sint16, Uint16, Sint32,
               Uint32, Sint64, Uint64, IntAP, IntAPS];
}

def IntegerAndFixedTypeClass : TypeClass {
  let Types = [Sint8, Uint8, Sint16, Uint16, Sint32,
               Uint32, Sint64, Uint64, IntAP, IntAPS, FixedPoint];
}

def IntegralTypeClass : TypeClass {
  let Types = !listconcat(IntegerTypeClass.Types, [Bool]);
}
def FixedSizeIntegralTypeClass : TypeClass {
  let Types = [Sint8, Uint8, Sint16, Uint16, Sint32,
               Uint32, Sint64, Uint64, Bool];
}

def FixedSizeIntegralNoBoolTypeClass : TypeClass {
  let Types = [Sint8, Uint8, Sint16, Uint16, Sint32, Uint32, Sint64, Uint64];
}

def NumberTypeClass : TypeClass {
  let Types = !listconcat(IntegerTypeClass.Types, [Float]);
}

def FloatTypeClass : TypeClass {
  let Types = [Float];
}

def AluTypeClass : TypeClass {
  let Types = !listconcat(IntegerTypeClass.Types, [Bool], [FixedPoint]);
}

def PtrTypeClass : TypeClass { let Types = [Ptr, MemberPtr]; }

def NonPtrTypeClass : TypeClass {
  let Types = !listconcat(IntegerTypeClass.Types, [Bool], [Float], [FixedPoint]);
}

def AllTypeClass : TypeClass {
  let Types = !listconcat(AluTypeClass.Types, PtrTypeClass.Types, FloatTypeClass.Types);
}

def ComparableTypeClass : TypeClass {
  let Types = !listconcat(AluTypeClass.Types, [Ptr], [Float]);
}

class SingletonTypeClass<Type Ty> : TypeClass {
  let Types = [Ty];
}

//===----------------------------------------------------------------------===//
// Record describing all opcodes.
//===----------------------------------------------------------------------===//

class Opcode {
  list<TypeClass> Types = [];
  list<ArgType> Args = [];
  string Name = "";
  bit CanReturn = 0;
  bit ChangesPC = 0;
  bit HasCustomLink = 0;
  bit HasCustomEval = 0;
  bit HasGroup = 0;
}

class AluOpcode : Opcode {
  let Types = [AluTypeClass];
  let HasGroup = 1;
}

class FloatOpcode : Opcode {
  let Args = [ArgUint32];
}

class IntegerOpcode : Opcode {
  let Types = [IntegerAndFixedTypeClass];
  let HasGroup = 1;
}

//===----------------------------------------------------------------------===//
// Jump opcodes
//===----------------------------------------------------------------------===//

class JumpOpcode : Opcode {
  let Args = [ArgSint32];
  let ChangesPC = 1;
  let HasCustomEval = 1;
}

// [] -> []
def Jmp : JumpOpcode;
// [Bool] -> [], jumps if true.
def Jt : JumpOpcode;
// [Bool] -> [], jumps if false.
def Jf : JumpOpcode;

def StartSpeculation : Opcode;
def EndSpeculation : Opcode;
def BCP : Opcode {
  let ChangesPC = 1;
  let HasCustomEval = 1;
  let Args = [ArgSint32, ArgPrimType];
}

//===----------------------------------------------------------------------===//
// Returns
//===----------------------------------------------------------------------===//

// [Value] -> []
def Ret : Opcode {
  let Types = [AllTypeClass];
  let ChangesPC = 1;
  let CanReturn = 1;
  let HasGroup = 1;
  let HasCustomEval = 1;
}
// [] -> []
def RetVoid : Opcode {
  let CanReturn = 1;
  let ChangesPC = 1;
  let HasCustomEval = 1;
}
// [Value] -> []
def RetValue : Opcode {
  let CanReturn = 1;
  let ChangesPC = 1;
  let HasCustomEval = 1;
}
// [] -> EXIT
def NoRet : Opcode {}


def Call : Opcode {
  let Args = [ArgFunction, ArgUint32];
}

def CallVirt : Opcode {
  let Args = [ArgFunction, ArgUint32];
}

def CallBI : Opcode { let Args = [ArgCallExpr, ArgUint32]; }

def CallPtr : Opcode {
  let Args = [ArgUint32, ArgCallExpr];
}

def CallVar : Opcode {
  let Args = [ArgFunction, ArgUint32];
}

def OffsetOf : Opcode {
  let Types = [IntegerTypeClass];
  let Args = [ArgOffsetOfExpr];
  let HasGroup = 1;
}

//===----------------------------------------------------------------------===//
// Frame management
//===----------------------------------------------------------------------===//

// [] -> []
def Destroy : Opcode {
  let Args = [ArgUint32];
  let HasCustomEval = 1;
}
def InitScope : Opcode {
  let Args = [ArgUint32];
}

//===----------------------------------------------------------------------===//
// Constants
//===----------------------------------------------------------------------===//

class ConstOpcode<Type Ty, ArgType ArgTy> : Opcode {
  let Types = [SingletonTypeClass<Ty>];
  let Args = [ArgTy];
  let Name = "Const";
}

// [] -> [Integer]
def ConstSint8 : ConstOpcode<Sint8, ArgSint8>;
def ConstUint8 : ConstOpcode<Uint8, ArgUint8>;
def ConstSint16 : ConstOpcode<Sint16, ArgSint16>;
def ConstUint16 : ConstOpcode<Uint16, ArgUint16>;
def ConstSint32 : ConstOpcode<Sint32, ArgSint32>;
def ConstUint32 : ConstOpcode<Uint32, ArgUint32>;
def ConstSint64 : ConstOpcode<Sint64, ArgSint64>;
def ConstUint64 : ConstOpcode<Uint64, ArgUint64>;
def ConstIntAP : ConstOpcode<IntAP, ArgIntAP>;
def ConstIntAPS : ConstOpcode<IntAPS, ArgIntAPS>;
def ConstBool : ConstOpcode<Bool, ArgBool>;
def ConstFixedPoint : ConstOpcode<FixedPoint, ArgFixedPoint>;

def ConstFloat : Opcode { let Args = [ArgFloat]; }

// [] -> [Integer]
def Zero : Opcode {
  let Types = [FixedSizeIntegralTypeClass];
  let HasGroup = 1;
}

def ZeroIntAP : Opcode {
  let Args = [ArgUint32];
}

def ZeroIntAPS : Opcode {
  let Args = [ArgUint32];
}

// [] -> [Pointer]
def Null : Opcode {
  let Types = [PtrTypeClass];
  let Args = [ArgUint64, ArgDesc];
  let HasGroup = 1;
}

//===----------------------------------------------------------------------===//
// Pointer generation
//===----------------------------------------------------------------------===//
class OffsetOpcode : Opcode {
  let Args = [ArgUint32];
}

// [] -> [Pointer]
def GetPtrLocal : OffsetOpcode {
  bit HasCustomEval = 1;
}
// [] -> [Pointer]
def GetPtrParam : OffsetOpcode;
// [] -> [Pointer]
def GetPtrGlobal : OffsetOpcode;
// [Pointer] -> [Pointer]
def GetPtrField : OffsetOpcode;
def GetPtrFieldPop : OffsetOpcode;
// [] -> [Pointer]
def GetPtrThisField : OffsetOpcode;
// [Pointer] -> [Pointer]
def GetPtrBase : OffsetOpcode;
// [Pointer] -> [Pointer]
def GetPtrBasePop : OffsetOpcode { let Args = [ArgUint32, ArgBool]; }
def GetMemberPtrBasePop : Opcode {
  // Offset of field, which is a base.
  let Args = [ArgSint32];
}

def FinishInitPop : Opcode;
def FinishInit : Opcode;
def FinishInitActivate : Opcode;
def FinishInitActivatePop : Opcode;
def FinishInitGlobal : Opcode;

def GetPtrDerivedPop : Opcode { let Args = [ArgUint32, ArgBool, ArgTypePtr]; }

// [Pointer] -> [Pointer]
def GetPtrVirtBasePop : Opcode {
  // RecordDecl of base class.
  let Args = [ArgRecordDecl];
}
// [] -> [Pointer]
def GetPtrThisBase : Opcode {
  // Offset of field, which is a base.
  let Args = [ArgUint32];
}
// [] -> [Pointer]
def GetPtrThisVirtBase : Opcode {
  // RecordDecl of base class.
  let Args = [ArgRecordDecl];
}
// [] -> [Pointer]
def This : Opcode;

// [] -> [Pointer]
def RVOPtr : Opcode;

// [Pointer] -> [Pointer]
def NarrowPtr : Opcode;
// [Pointer] -> [Pointer]
def ExpandPtr : Opcode;
// [Pointer, Offset] -> [Pointer]
def ArrayElemPtr : AluOpcode;
def ArrayElemPtrPop : AluOpcode;

def ArrayElemPop : Opcode {
  let Args = [ArgUint32];
  let Types = [AllTypeClass];
  let HasGroup = 1;
}

def ArrayElem : Opcode {
  let Args = [ArgUint32];
  let Types = [AllTypeClass];
  let HasGroup = 1;
}

def CopyArray : Opcode {
  let Args = [ArgUint32, ArgUint32, ArgUint32];
  let Types = [AllTypeClass];
  let HasGroup = 1;
}

//===----------------------------------------------------------------------===//
// Direct field accessors
//===----------------------------------------------------------------------===//

class AccessOpcode : Opcode {
  let Types = [AllTypeClass];
  let Args = [ArgUint32];
  let HasGroup = 1;
}

class BitFieldOpcode : Opcode {
  let Types = [IntegralTypeClass];
  let Args = [ArgRecordField];
  let HasGroup = 1;
}

// [] -> [Pointer]
def GetLocal : AccessOpcode { let HasCustomEval = 1; }
// [] -> [Pointer]
def SetLocal : AccessOpcode { let HasCustomEval = 1; }

def EndLifetimePop : Opcode;
def EndLifetime : Opcode;
def StartLifetime : Opcode;

def CheckDecl : Opcode {
  let Args = [ArgVarDecl];
}

def CheckEnumValue : Opcode {
  let Args = [ArgEnumDecl];
  let Types = [IntegralTypeClass];
  let HasGroup = 1;
}

def CheckLiteralType : Opcode {
  let Args = [ArgTypePtr];
}

def CheckArraySize : Opcode { let Args = [ArgUint64]; }

// [] -> [Value]
def GetGlobal : AccessOpcode;
def GetGlobalUnchecked : AccessOpcode;
// [Value] -> []
def InitGlobal : AccessOpcode;
// [Value] -> []
def InitGlobalTemp : AccessOpcode {
  let Args = [ArgUint32, ArgLETD];
}
// [Pointer] -> [Pointer]
def InitGlobalTempComp : Opcode {
  let Args = [ArgLETD];
}
// [Value] -> []
def SetGlobal : AccessOpcode;

// [] -> [Value]
def GetParam : AccessOpcode;
// [Value] -> []
def SetParam : AccessOpcode;

// [Pointer] -> [Pointer, Value]
def GetField : AccessOpcode;
// [Pointer] -> [Value]
def GetFieldPop : AccessOpcode;
// [] -> [Value]
def GetThisField : AccessOpcode;

// [Pointer, Value] -> [Pointer]
def SetField : AccessOpcode;
// [Value] -> []
def SetThisField : AccessOpcode;

// [Value] -> []
def InitThisField : AccessOpcode;
def InitThisFieldActivate : AccessOpcode;
// [Value] -> []
def InitThisBitField : Opcode {
  let Types = [AluTypeClass];
  let Args = [ArgRecordField, ArgUint32];
  let HasGroup = 1;
}
def InitThisBitFieldActivate : Opcode {
  let Types = [AluTypeClass];
  let Args = [ArgRecordField, ArgUint32];
  let HasGroup = 1;
}
// [Pointer, Value] -> []
def InitField : AccessOpcode;
def InitFieldActivate : AccessOpcode;
// [Pointer, Value] -> []
def InitBitField : BitFieldOpcode;
def InitBitFieldActivate : BitFieldOpcode;

//===----------------------------------------------------------------------===//
// Pointer access
//===----------------------------------------------------------------------===//

class LoadOpcode : Opcode {
  let Types = [AllTypeClass];
  let HasGroup = 1;
}

// [Pointer] -> [Pointer, Value]
def Load : LoadOpcode {}
// [Pointer] -> [Value]
def LoadPop : LoadOpcode {}

class StoreOpcode : Opcode {
  let Types = [AllTypeClass];
  let HasGroup = 1;
}

class StoreBitFieldOpcode : Opcode {
  let Types = [AluTypeClass];
  let HasGroup = 1;
}

def Store : StoreOpcode {}
def StorePop : StoreOpcode {}
def StoreActivatePop : StoreOpcode {}
def StoreActivate : StoreOpcode {}
def StoreBitField : StoreBitFieldOpcode {}
def StoreBitFieldPop : StoreBitFieldOpcode {}
def StoreBitFieldActivate : StoreBitFieldOpcode {}
def StoreBitFieldActivatePop : StoreBitFieldOpcode {}

def Activate : Opcode {}
def ActivateThisField : Opcode { let Args = [ArgUint32]; }

// [Pointer, Value] -> []
def Init : StoreOpcode {}
def InitPop : StoreOpcode {}
// [Pointer, Value] -> [Pointer]
def InitElem : Opcode {
  let Types = [AllTypeClass];
  let Args = [ArgUint32];
  let HasGroup = 1;
}
// [Pointer, Value] -> []
def InitElemPop : Opcode {
  let Types = [AllTypeClass];
  let Args = [ArgUint32];
  let HasGroup = 1;
}

//===----------------------------------------------------------------------===//
// Pointer arithmetic.
//===----------------------------------------------------------------------===//

// [Pointer, Integral] -> [Pointer]
def AddOffset : AluOpcode;
// [Pointer, Integral] -> [Pointer]
def SubOffset : AluOpcode;

// [Pointer, Pointer] -> [Integral]
def SubPtr : Opcode {
  let Types = [IntegerTypeClass];
  let HasGroup = 1;
}

// [Pointer] -> [Pointer]
def IncPtr : Opcode;
// [Pointer] -> [Pointer]
def DecPtr : Opcode;

//===----------------------------------------------------------------------===//
// Function pointers.
//===----------------------------------------------------------------------===//
def GetFnPtr : Opcode {
  let Args = [ArgFunction];
}

def GetIntPtr : Opcode {
  let Types = [AluTypeClass];
  let Args = [ArgDesc];
  let HasGroup = 1;
}

//===----------------------------------------------------------------------===//
// Binary operators.
//===----------------------------------------------------------------------===//

// [Real, Real] -> [Real]
def Add  : AluOpcode;
def Addf : FloatOpcode;
def Sub  : AluOpcode;
def Subf : FloatOpcode;
def Mul  : AluOpcode;
def Mulf : FloatOpcode;
def Mulc : Opcode {
  let Types = [NumberTypeClass];
  let HasGroup = 1;
}
def Rem  : IntegerOpcode;
def Div  : IntegerOpcode;
def Divf : FloatOpcode;
def Divc : Opcode {
  let Types = [NumberTypeClass];
  let HasGroup = 1;
}

def BitAnd : IntegerOpcode;
def BitOr : IntegerOpcode;
def BitXor : IntegerOpcode;

def Shl : Opcode {
  let Types = [IntegerTypeClass, IntegerTypeClass];
  let HasGroup = 1;
}

def Shr : Opcode {
  let Types = [IntegerTypeClass, IntegerTypeClass];
  let HasGroup = 1;
}

//===----------------------------------------------------------------------===//
// Unary operators.
//===----------------------------------------------------------------------===//

// [Bool] -> [Bool]
def Inv: Opcode;

// Increment and decrement.
class OverflowOpcode : Opcode {
  let Types = [AluTypeClass];
  let Args = [ArgBool];
  let HasGroup = 1;
}

def Inc : OverflowOpcode;
def IncPop : OverflowOpcode;
def PreInc : OverflowOpcode;
def Dec : OverflowOpcode;
def DecPop : OverflowOpcode;
def PreDec : OverflowOpcode;

// Float increment and decrement.
def Incf: FloatOpcode;
def IncfPop : FloatOpcode;
def Decf: FloatOpcode;
def DecfPop : FloatOpcode;

// [Real] -> [Real]
def Neg: Opcode {
  let Types = [NonPtrTypeClass];
  let HasGroup = 1;
}

// [Real] -> [Real]
def Comp: Opcode {
  let Types = [IntegerTypeClass];
  let HasGroup = 1;
}

def IsNonNull : Opcode {
  let Types = [PtrTypeClass];
  let HasGroup = 1;
}

//===----------------------------------------------------------------------===//
// Cast, CastFP.
//===----------------------------------------------------------------------===//

def FromCastTypeClass : TypeClass {
  let Types = [Uint8, Sint8, Uint16, Sint16, Uint32, Sint32, Uint64, Sint64, Bool, IntAP, IntAPS, FixedPoint];
}

def ToCastTypeClass : TypeClass {
  let Types = [Uint8, Sint8, Uint16, Sint16, Uint32, Sint32, Uint64, Sint64, Bool];
}

def Cast: Opcode {
  let Types = [FromCastTypeClass, ToCastTypeClass];
  let HasGroup = 1;
}

def CastFP : Opcode {
  let Args = [ArgFltSemantics, ArgRoundingMode];
}

def CastFixedPoint : Opcode {
  let Args = [ArgUint32];
}

def CastAP : Opcode {
  let Types = [AluTypeClass];
  let Args = [ArgUint32];
  let HasGroup = 1;
}

def CastAPS : Opcode {
  let Types = [AluTypeClass];
  let Args = [ArgUint32];
  let HasGroup = 1;
}

// Cast an integer to a floating type
def CastIntegralFloating : Opcode {
  let Types = [AluTypeClass];
  let Args = [ArgFltSemantics, ArgUint32];
  let HasGroup = 1;
}

// Cast a floating to an integer type
def CastFloatingIntegral : Opcode {
  let Types = [FixedSizeIntegralTypeClass];
  let Args = [ArgUint32];
  let HasGroup = 1;
}

def CastFloatingIntegralAP : Opcode {
  let Args = [ArgUint32, ArgUint32];
}

def CastFloatingIntegralAPS : Opcode {
  let Args = [ArgUint32, ArgUint32];
}

def CastPointerIntegral : Opcode {
  let Types = [FixedSizeIntegralTypeClass];
  let HasGroup = 1;
}
def CastPointerIntegralAP : Opcode {
  let Args = [ArgUint32];
}
def CastPointerIntegralAPS : Opcode {
  let Args = [ArgUint32];
}
def CastIntegralFixedPoint : Opcode {
  let Types = [FixedSizeIntegralTypeClass];
  let Args = [ArgUint32];
  let HasGroup = 1;
}
def CastFloatingFixedPoint : Opcode {
  let Args = [ArgUint32];
}
def CastFixedPointFloating : Opcode {
  let Args = [ArgFltSemantics];
}
def CastFixedPointIntegral : Opcode {
  let Types = [FixedSizeIntegralNoBoolTypeClass];
  let HasGroup = 1;
}
def ShiftFixedPoint : Opcode {
  let Args = [ArgBool];
}

def PtrPtrCast : Opcode {
  let Args = [ArgBool];

}

def FnPtrCast : Opcode;

def DecayPtr : Opcode {
  let Types = [PtrTypeClass, PtrTypeClass];
  let HasGroup = 1;
}

//===----------------------------------------------------------------------===//
// Comparison opcodes.
//===----------------------------------------------------------------------===//

class EqualityOpcode : Opcode {
  let Types = [AllTypeClass];
  let HasGroup = 1;
}

def EQ : EqualityOpcode;
def NE : EqualityOpcode;

class ComparisonOpcode : Opcode {
  let Types = [ComparableTypeClass];
  let HasGroup = 1;
}

def CMP3 : ComparisonOpcode {
  let Args = [ArgCCI];
}

def LT : ComparisonOpcode;
def LE : ComparisonOpcode;
def GT : ComparisonOpcode;
def GE : ComparisonOpcode;

//===----------------------------------------------------------------------===//
// Stack management.
//===----------------------------------------------------------------------===//

// [Value] -> []
def Pop : Opcode {
  let Types = [AllTypeClass];
  let HasGroup = 1;
}

// [Value] -> [Value, Value]
def Dup : Opcode {
  let Types = [AllTypeClass];
  let HasGroup = 1;
}

def Flip : Opcode {
  let Types = [AllTypeClass, AllTypeClass];
  let HasGroup = 1;
}

// [] -> []
def Invalid : Opcode {}
def Unsupported : Opcode {}
def Error : Opcode {}
def SideEffect : Opcode {}
def InvalidCast : Opcode {
  let Args = [ArgCastKind, ArgBool];
}
def CheckPseudoDtor : Opcode {}

def InvalidDeclRef : Opcode {
  let Args = [ArgDeclRef, ArgBool];
}

def SizelessVectorElementSize : Opcode;
def InvalidShuffleVectorIndex : Opcode {
  let Args = [ArgUint32];
}

def Assume : Opcode;

def ArrayDecay : Opcode;

def CheckNonNullArg : Opcode {
  let Types = [PtrTypeClass];
  let HasGroup = 1;
}

def Memcpy : Opcode;

def ToMemberPtr : Opcode;
def CastMemberPtrPtr : Opcode;
def GetMemberPtr : Opcode {
  let Args = [ArgValueDecl];
}
def GetMemberPtrBase : Opcode;
def GetMemberPtrDecl : Opcode;

//===----------------------------------------------------------------------===//
// Debugging.
//===----------------------------------------------------------------------===//
def Dump : Opcode;

def Alloc : Opcode {
  let Args = [ArgDesc];
}

def AllocN : Opcode {
  let Types = [IntegerTypeClass];
  let Args = [ArgPrimType, ArgExpr, ArgBool];
  let HasGroup = 1;
}

def AllocCN : Opcode {
  let Types = [IntegerTypeClass];
  let Args = [ArgDesc, ArgBool];
  let HasGroup = 1;
}

def Free : Opcode {
  let Args = [ArgBool, ArgBool];
}

def CheckNewTypeMismatch : Opcode {
  let Args = [ArgExpr];
}

def InvalidNewDeleteExpr : Opcode {
  let Args = [ArgExpr];
}

def CheckNewTypeMismatchArray : Opcode {
  let Types = [IntegerTypeClass];
  let Args = [ArgExpr];
  let HasGroup = 1;
}

def IsConstantContext: Opcode;
def CheckAllocations : Opcode;
def CheckNull : Opcode;

def BitCastTypeClass : TypeClass {
  let Types = [Uint8, Sint8, Uint16, Sint16, Uint32, Sint32, Uint64, Sint64,
               IntAP, IntAPS, Bool, Float, Ptr];
}

def BitCastPrim : Opcode {
  let Types = [BitCastTypeClass];
  let Args = [ArgBool, ArgUint32, ArgFltSemantics];
  let HasGroup = 1;
}

def BitCast : Opcode;

def GetTypeid : Opcode { let Args = [ArgTypePtr, ArgTypePtr]; }
def GetTypeidPtr : Opcode { let Args = [ArgTypePtr]; }
def DiagTypeid : Opcode;

def CheckDestruction : Opcode;

def PushCC : Opcode { let Args = [ArgBool]; }
def PopCC : Opcode;
