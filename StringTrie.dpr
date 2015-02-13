Program StringTrie;

{$APPTYPE CONSOLE}

Uses
  FastMemoryManager, FastMemoryManagerMessages,
  SysUtils, Windows, Math, Classes;


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

    Procedure Add(Const sValue : String; pData : Pointer); Overload;
    Procedure Add(Const sValue : String; iValue : Integer); Overload;
    Function TryFind(pValue : PChar; Out pData : Pointer) : Boolean;
    Function Find(pValue : PChar) : Pointer;

    Procedure Dump(iDepth : Integer = 0);
    Procedure DumpKeys(sValue : String = '');

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
      If iLen = Length(sValue) Then
      Begin
        FChildren[iLoop].Terminal := True;
        FChildren[iLoop].Data := pData;
      End
      Else
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


Procedure TTrieNode.Add(Const sValue : String; iValue : Integer);
Begin
  Add(sValue, Pointer(iValue));
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


Procedure TTrieNode.DumpKeys(sValue : String);
Var
  iIndex : Integer;
Begin
  If FTerminal Then
    Writeln(sValue + FValue);
  For iIndex := 0 To FCount - 1 Do
    FChildren[iIndex].DumpKeys(sValue + FValue);
End;


Var
  oList : TStringList;
  oTrie : TTrieNode;
  pData : Pointer;
  iIndex, iJ : Integer;
Begin
  Randomize;

  oTrie := TTrieNode.Create;
  Try
    oTrie.Add('A', 1);
    oTrie.Add('A', 2);
  Finally
    oTrie.Free;
  End;

  oList := TStringList.Create;
  Try
    oList.LoadFromFile('c:\development\compile\hash.txt');

    While True Do
    Begin
      oTrie := TTrieNode.Create;
      Try
        For iIndex := oList.Count - 1 DownTo 1 Do
        Begin
          iJ := Random(iIndex);
          oList.Exchange(iIndex, iJ);
        End;

        For iIndex := 0 To oList.Count - 1 Do
        Begin
          oTrie.Add(oList[iIndex], Pointer($1));
          If oTrie.Count <> (iIndex + 1) Then
          Begin
            Writeln(iIndex);
          End;
        End;

        Write('.');
      Finally
        oTrie.Free;
      End;
    End;

    {Writeln;
    oTrie.DumpKeys;
    Writeln;
    oTrie.Dump;

    Readln;}
  Finally
    oList.Free;
  End;
End.
