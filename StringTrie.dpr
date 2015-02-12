Program StringTrie;

{$APPTYPE CONSOLE}

Uses
  FastMemoryManager, FastMemoryManagerMessages,
  SysUtils, Windows, Math;


Type               
  TTrieNode = Class
  Private
    FCount : Integer;
    FValue : String;
    FData : Pointer;
    FTerminal : Boolean;
    FChildren : Array Of TTrieNode;

    Function GetChildren(iIndex : Integer) : TTrieNode;
    Function GetCount : Integer;

    Procedure Insert(iIndex : Integer);
    Function PrefixLength(Const sA, sB : String) : Integer;

  Public
    Destructor Destroy; Override;

    Procedure Add(Const sValue : String; pData : Pointer);
    Function TryFind(pValue : PChar; Out pData : Pointer) : Boolean;
    Function Find(pValue : PChar) : Pointer;

    Procedure Dump(iDepth : Integer = 0);

    Property Value : String Read FValue Write FValue;
    Property Data : Pointer Read FData Write FData;
    Property Terminal : Boolean Read FTerminal Write FTerminal;
    Property Children[iIndex : Integer] : TTrieNode Read GetChildren; Default;
    Property Count : Integer Read GetCount;
  End;


Function TTrieNode.GetChildren(iIndex : Integer) : TTrieNode;
Begin
  Result := FChildren[iIndex];
End;


Function TTrieNode.GetCount : Integer;
Var
  iIndex : Integer;
Begin
  Result := 0;
  If FTerminal Then
    Inc(Result);
  For iIndex := 0 To FCount - 1 Do
    Inc(Result, FChildren[iIndex].Count);
End;


Procedure TTrieNode.Insert(iIndex : Integer);
Begin
  If FCount = 0 Then
    SetLength(FChildren, 4)
  Else If FCount = Length(FChildren) Then
    SetLength(FChildren, Length(FChildren) * 2);

  MoveMemory(@FChildren[iIndex + 1], @FChildren[iIndex], (FCount - iIndex) * SizeOf(TTrieNode));
End;


Function TTrieNode.PrefixLength(Const sA, sB : String) : Integer;
Var
  iIndex, iMax : Integer;
Begin
  iIndex := 1;
  iMax := Min(Length(sA), Length(sB));

  While (iIndex <= iMax) And (sA[iIndex] = sB[iIndex]) Do
    Inc(iIndex);

  Result := iIndex - 1;
End;


Destructor TTrieNode.Destroy;
Var
  iIndex : Integer;
Begin
  For iIndex := 0 To FCount - 1 Do
    FChildren[iIndex].Free;
  Inherited;
End;

Procedure TTrieNode.Add(Const sValue : String; pData : Pointer);
Var
  oNode : TTrieNode;
  iLoop, iLen : Integer;
Begin
  oNode := Nil;
  iLoop := 0;
  While iLoop < FCount Do
  Begin
    iLen := PrefixLength(sValue, FChildren[iLoop].Value);
    If iLen = Length(FChildren[iLoop].Value) Then
    Begin
      FChildren[iLoop].Add(Copy(sValue, iLen + 1, MaxInt), pData);
      Exit;
    End
    Else If iLen > 0 Then
    Begin
      // split
      If iLen < Length(FChildren[iLoop].Value) Then
      Begin
        // create a new parent node with the prefix
        oNode := TTrieNode.Create;
        oNode.Value := Copy(FChildren[iLoop].Value, 1, iLen);

        // update the old child to the suffix
        FChildren[iLoop].Value := Copy(FChildren[iLoop].Value, iLen + 1, MaxInt);

        // move the old subtree to the new child
        SetLength(oNode.FChildren, 4);
        oNode.FChildren[0] := FChildren[iLoop];
        oNode.FCount := 1;
        FChildren[iLoop] := oNode;
      End;
      // Add the new key
      FChildren[iLoop].Add(Copy(sValue, iLen + 1, MaxInt), pData);
      Exit;
    End
    Else If StrComp(PChar(sValue), PChar(FChildren[iLoop].Value)) <= 0 Then
    Begin
      // insert
      Break;
    End;
    Inc(iLoop);                                                  
  End;

  Insert(iLoop);
  FChildren[iLoop] := TTrieNode.Create;
  FChildren[iLoop].Value := sValue;
  FChildren[iLoop].Data := pData;
  FChildren[iLoop].Terminal := True;
  Inc(FCount);
End;


Function TTrieNode.TryFind(pValue : PChar; Out pData : Pointer) : Boolean;
Var
  oNode : TTrieNode;
  iIndex, iLen : Integer;
Begin
  Result := False;
  If pValue^ = #0 Then
  Begin
    Result := Terminal;
    If Result Then
      pData := Data;
  End
  Else
  Begin
    iIndex := 0;
    While (iIndex < FCount) And Not Result Do
    Begin
      oNode := FChildren[iIndex];
      iLen := Length(oNode.Value);
      If StrLComp(pValue, PChar(oNode.Value), iLen) = 0 Then
      Begin
        Inc(pValue, iLen);
        Result := oNode.TryFind(pValue, pData);
      End;

      Inc(iIndex);
    End;
  End;
End;


Function TTrieNode.Find(pValue : PChar) : Pointer;
Var
  bFound : Boolean;
Begin
  bFound := TryFind(pValue, Result);
  If Not bFound Then
    Raise Exception.Create('Key not found');
End;


Procedure TTrieNode.Dump(iDepth : Integer);
Var
  sPrefix : String;
  iLoop : Integer;
Begin
  sPrefix := '';
  For iLoop := 1 To iDepth Do
    sPrefix := sPrefix + '  ';

  For iLoop := 0 To FCount - 1 Do
  Begin
    Writeln(sPrefix, FChildren[iLoop].Value, ' - ', Cardinal(FChildren[iLoop].Data));
    FChildren[iLoop].Dump(iDepth + 1);
  End;
End;

Var
  oRoot, oNode : TTrieNode;
  pData : Pointer;

Begin
  oRoot := TTrieNode.Create;
  Try
{
    oRoot.Add('TFoo', Pointer($1));
    oRoot.Add('TBar', Pointer($3));
    oRoot.Add('TFooList', Pointer($2));
    oRoot.Add('C', Pointer($2));
    oRoot.Add('BA', Pointer($4));
    oRoot.Add('A', Pointer($5));
    oRoot.Add('F', Pointer($6));
    oRoot.Add('Baz', Pointer($7));

    Writeln(oRoot.Count);

    oNode := oRoot[0];

    Writeln(oRoot.TryFind('T', pData) = False);
    Writeln(oRoot.TryFind('TF', pData) = False);
    Writeln(oRoot.TryFind('TFoo', pData) = True);
    Writeln(oRoot.TryFind('BAZ', pData) = False);
    Writeln(oRoot.TryFind('Baz', pData) = True);
    Writeln(oRoot.TryFind('TFooList', pData) = True);
    Writeln(oRoot.TryFind('TFooL', pData) = False);
    Writeln(oRoot.TryFind('Z', pData) = False);
    Writeln(oRoot.TryFind('', pData) = False);
}

//    oRoot.Add('EAbstractContract', Pointer($1));
//    oRoot.Add('EAbstractError', Pointer($1));
//    oRoot.Add('EAccessViolation', Pointer($1));
    oRoot.Add('EAdvAbstract', Pointer($1));
    oRoot.Add('EAdvAssertion', Pointer($1));
    oRoot.Add('EAdvException', Pointer($1));
{    oRoot.Add('EAdvFactory', Pointer($1));
    oRoot.Add('EAdvInvariant', Pointer($1));
    oRoot.Add('EAdvManager', Pointer($1));
    oRoot.Add('EAdvReadWriteCriticalSection', Pointer($1));
    oRoot.Add('EApplicationServerTask', Pointer($1));
    oRoot.Add('EApplicationStorageInsert', Pointer($1));
    oRoot.Add('EApplicationStorageUpdate', Pointer($1));
}
    Writeln;
    oRoot.Dump;

  Finally
    oRoot.Free;
  End;

  Readln;

End.
