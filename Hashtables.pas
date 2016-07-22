Unit Hashtables;

Interface

Uses
  StringSupport,
  AdvObjects, AdvExceptions;

Type

  THashTable = Class;
  THashTableEnumerator = Class;

  THashKey = Int64;
  THashValue = Int64;

  THashEntry = Record
    HashCode : Integer;
    Next : Integer;
    Key : THashKey;
    Value : THashValue;
  End;

  TIntegerArray = Array Of Integer;
  THashEntryArray = Array Of THashEntry;
  
  THashTable = Class(TAdvObject)
  Private
    FVersion : Integer;
    FCount : Integer;
    FFreeCount : Integer;
    FFreeList : Integer;

    FBuckets : TIntegerArray;
    FEntries : THashEntryArray;

    Function GetCount : Integer;

  Protected
    Procedure Initialize(iCapacity : Integer);
    Procedure Resize; Overload;
    Procedure Resize(iNewSize : Integer; bRehash : Boolean); Overload;

    Procedure Insert(Const aKey : THashKey; Const aValue : THashValue; bAdd : Boolean);
    Function FindEntry(Const aKey : THashKey) : Integer;

  Public
    Constructor Create; Overload; Override; 
    Constructor Create(iCapacity : Integer); Overload;

    Procedure Add(Const aKey : THashKey; Const aValue : THashValue);
    Function TryGetValue(Const aKey : THashKey; Out aValue : THashValue) : Boolean;
    Function Remove(Const aKey : THashKey) : Boolean;

    Function GetEnumerator : THashTableEnumerator;

    Property Count : Integer Read GetCount;
  End;

  THashTableEnumerator = Class(TAdvObject)
  Private
    FCurrentKey : THashKey;
    FCurrentValue : THashValue;

    FHashTable : THashTable;
    FVersion : Integer;
    FIndex : Integer;

  Public
    Constructor Create; Override;

    Function MoveNext : Boolean;

    Property CurrentKey : THashKey Read FCurrentKey;
    Property CurrentValue : THashValue Read FCurrentValue;
  End;

  TCacheTableLocker = Class(TAdvObject)
  End;

  TCacheEntry = Class(TAdvObject)
  End;

  TCacheTable = Class(TAdvObject)
  End;

Implementation

Const

  KNOWN_PRIMES : Array[0..71] Of Integer = (
    3, 7, 11, $11, $17, $1d, $25, $2f, $3b, $47, $59, $6b, $83, $a3, $c5, $ef,
    $125, $161, $1af, $209, $277, $2f9, $397, $44f, $52f, $63d, $78b, $91d, $af1, $d2b, $fd1, $12fd,
    $16cf, $1b65, $20e3, $2777, $2f6f, $38ff, $446f, $521f, $628d, $7655, $8e01, $aa6b, $cc89, $f583, $126a7, $1619b,
    $1a857, $1fd3b, $26315, $2dd67, $3701b, $42023, $4f361, $5f0ed, $72125, $88e31, $a443b, $c51eb, $ec8c1, $11bdbf, $154a3f, $198c4f,
    $1ea867, $24ca19, $2c25c1, $34fa1b, $3f928f, $4c4987, $5b8b6f, $6dda89
  );

Function GetPrime(iMin : Integer) : Integer;
Var
  iIndex : Integer;
Begin
  iIndex := 0;
  While KNOWN_PRIMES[iIndex] < iMin Do
    Inc(iIndex);
  If iIndex < Length(KNOWN_PRIMES) Then
    Result := KNOWN_PRIMES[iIndex]
  Else
  Begin
    // TODO: Calculate larger primes
    Raise EAdvException.Create('Not implemented');
  End;
End;


Function GetHashCode(Const aValue : THashKey) : Integer;
Begin
  Result := (Integer(aValue Shr 32)) Xor (Integer(aValue));
End;


Function KeyEquals(Const aValue, bValue : THashKey) : Boolean;
Begin
  Result := aValue = bValue;
End;


Function KeyToString(Const aValue : THashKey) : String;
Begin
  Result := StringFormat('%d', [aValue]);
End;


Function THashTable.GetCount : Integer;
Begin
  Result := FCount - FFreeCount;
End;


Procedure THashTable.Initialize(iCapacity : Integer);
Var
  iPrime, iLoop : Integer;
Begin
  iPrime := GetPrime(iCapacity);

  SetLength(FBuckets, iPrime);
  For iLoop := 0 To Length(FBuckets) - 1 Do
    FBuckets[iLoop] := -1;

  SetLength(FEntries, iPrime);
  FFreeList := -1;
End;


Procedure THashTable.Resize;
Begin
  Resize(GetPrime(FCount), False);
End;


Procedure THashTable.Resize(iNewSize : Integer; bRehash : Boolean);
Var
  aNumArray : TIntegerArray;
  aDestinationArray : THashEntryArray;
  i, j, k, iIndex : Integer;
Begin
  aNumArray := Nil;
  aDestinationArray := Nil;

  SetLength(aNumArray, iNewSize);
  For i := 0 To Length(aNumArray) - 1 Do
    aNumArray[i] := -1;

  SetLength(aDestinationArray, iNewSize);
  Move(FEntries[0], aDestinationArray[0], FCount * SizeOf(THashEntry));

  If bRehash Then
  Begin
    For k := 0 To FCount - 1 Do
    Begin
      If aDestinationArray[k].HashCode <> -1 Then
        aDestinationArray[k].HashCode := GetHashCode(aDestinationArray[k].Key) And MaxInt;
    End;
  End;

  For j := 0 To FCount - 1 Do
  Begin
    If aDestinationArray[j].HashCode >= 0 Then
    Begin
      iIndex := aDestinationArray[j].HashCode Mod iNewSize;
      aDestinationArray[j].Next := aNumArray[iIndex];
      aNumArray[iIndex] := j;
    End;
  End;

//  FBuckets := aNumArray;
//  FEntries := aDestinationArray;
End;


Procedure THashTable.Insert(Const aKey : THashValue; Const aValue : THashValue; bAdd : Boolean);
Var
  iNum, iIndex, i, iFreeList : Integer;
//  iNum3 : Integer;
Begin
  If Not Assigned(FBuckets) Then
    Initialize(0);

  iNum := GetHashCode(aKey) And MaxInt;
  iIndex := iNum Mod Length(FBuckets);
//  iNum3 := 0;

  i := FBuckets[iIndex];
  While i >= 0 Do
  Begin
    If (FEntries[i].HashCode = iNum) And KeyEquals(FEntries[i].Key, aKey) Then
    Begin
      If bAdd Then
        Error('Insert', StringFormat('Key %s already present', [KeyToString(aKey)]));

      FEntries[i].Value := aValue;
      Inc(FVersion);
      Exit;
    End;
//    Inc(iNum3);
    i := FEntries[i].Next;
  End;

  If FFreeCount > 0 Then
  Begin
    iFreeList := FFreeList;
    FFreeList := FEntries[iFreeList].Next;
    Dec(FFreeCount);
  End
  Else
  Begin
    If FCount = Length(FEntries) Then
    Begin
       Resize;
       iIndex := iNum Mod Length(FBuckets);
    End;
    iFreeList := FCount;
    Inc(FCount);
  End;

  FEntries[iFreeList].HashCode := iNum;
  FEntries[iFreeList].Next := FBuckets[iIndex];
  FEntries[iFreeList].Key := aKey;
  FEntries[iFreeList].Value := aValue;
  FBuckets[iIndex] := iFreeList;
  Inc(FVersion);

  {If iNum3 > 100 Then
  Begin
    RandomizeComparer;
    Resize(Length(FEentries), True);
  End;}
End;


Function THashTable.FindEntry(Const aKey : THashKey) : Integer;
Var
  iNum, i : Integer;
Begin
  If Assigned(FBuckets) Then
  Begin
    iNum := GetHashCode(aKey) And MaxInt;
    i := FBuckets[iNum Mod Length(FBuckets)];
    While i >= 0 Do
    Begin
      If (FEntries[i].HashCode = iNum) And KeyEquals(FEntries[i].Key, aKey) Then
      Begin
        Result := i;
        Exit;
      End;
      i := FEntries[i].Next;
    End;
  End;
  Result := -1;
End;


Constructor THashTable.Create;
Begin
  Create(0);
End;


Constructor THashTable.Create(iCapacity : Integer);
Begin
  Initialize(iCapacity);
End;


Procedure THashTable.Add(Const aKey : THashKey; Const aValue : THashValue);
Begin
  Insert(aKey, aValue, True);
End;


Function THashTable.TryGetValue(Const aKey : THashKey; Out aValue : THashValue) : Boolean;
Var
  iIndex : Integer;
Begin
  iIndex := FindEntry(aKey);
  Result := iIndex >= 0;

  If Result Then
    aValue := FEntries[iIndex].Value
  Else
    FillChar(aValue, SizeOf(THashValue), 0);
End;


Function THashTable.Remove(Const aKey : THashKey) : Boolean;
Var
  iNum, iIndex, iNum3, i : Integer;
Begin
  If Assigned(FBuckets) Then
  Begin
    iNum := GetHashCode(aKey) And MaxInt;
    iIndex := iNum Mod Length(FBuckets);
    iNum3 := -1;

    i := FBuckets[iIndex];
    While i >= 0 Do
    Begin
      If (FEntries[i].HashCode = iNum) And KeyEquals(FEntries[i].Key, aKey) Then
      Begin
        If iNum3 < 0 Then
          FBuckets[iIndex] := FEntries[i].Next
        Else
          FEntries[iNum3].Next := FEntries[i].Next;

        FEntries[i].HashCode := -1;
        FEntries[i].Next := FFreeList;
        FillChar(FEntries[i].Key, SizeOf(THashKey), 0);
        FillChar(FEntries[i].Value, SizeOf(THashValue), 0);
        FFreeList := i;
        Inc(FFreeCount);
        Inc(FVersion);

        Result := True;
        Exit;
      End;
      iNum3 := i;
      i := FEntries[i].Next;
    End;
  End;

  Result := False;
End;


Function THashTable.GetEnumerator : THashTableEnumerator;
Begin
  Result := THashTableEnumerator.Create;
  Result.FHashTable := Self;
  Result.FVersion := FVersion;
End;


Constructor THashTableEnumerator.Create;
Begin
  Inherited;
End;


Function THashTableEnumerator.MoveNext : Boolean;
Begin
  If FVersion <> FHashTable.FVersion Then
    Error('MoveNext', 'Underlying hashtable was changed during enumeration');

  While FIndex < FHashTable.FCount Do
  Begin
    If FHashTable.FEntries[FIndex].HashCode >= 0 Then
    Begin
      FCurrentKey := FHashTable.FEntries[FIndex].Key;
      FCurrentValue := FHashTable.FEntries[FIndex].Value;
      Inc(FIndex);
      Result := True;
      Exit;
    End;
    Inc(FIndex);
  End;

  FIndex := FHashTable.FCount + 1;
  FillChar(FCurrentKey, SizeOf(THashKey), 0);
  FillChar(FCurrentValue, SizeOf(THashValue), 0);
  Result := False;
End;


End.