
with Ada.Unchecked_Deallocation;
with Ada.Assertions; use Ada.Assertions;
with Util; use Util;
with BRAM;
with Random_Enum;

package body Memory.Cache is

   function Create_Cache(mem           : access Memory_Type'Class;
                         line_count    : Positive := 1;
                         line_size     : Positive := 8;
                         associativity : Positive := 1;
                         latency       : Time_Type := 1;
                         policy        : Policy_Type := LRU;
                         exclusive     : Boolean := False;
                         write_back    : Boolean := True)
                         return Cache_Pointer is
      result : constant Cache_Pointer := new Cache_Type;
   begin
      Set_Memory(result.all, mem);
      result.line_size     := line_size;
      result.line_count    := line_count;
      result.associativity := associativity;
      result.latency       := latency;
      result.policy        := policy;
      result.exclusive     := exclusive;
      result.write_back    := write_back;
      result.data.Set_Length(Count_Type(result.line_count));
      for i in 0 .. result.line_count - 1 loop
         result.data.Replace_Element(i, new Cache_Data);
      end loop;
      return result;
   end Create_Cache;

   function Random_Policy is new Random_Enum(Policy_Type);

   function Random_Boolean is new Random_Enum(Boolean);

   function Random_Cache(generator  : RNG.Generator;
                         max_cost   : Cost_Type)
                         return Memory_Pointer is
      result : Cache_Pointer := new Cache_Type;
   begin

      -- Start with everything set to the minimum.
      result.line_size     := 1;
      result.line_count    := 1;
      result.associativity := 1;
      result.latency       := 2;
      result.policy        := LRU;
      result.exclusive     := False;
      result.write_back    := True;

      -- If even the minimum cache is too costly, return nulll.
      if Get_Cost(result.all) > max_cost then
         Destroy(Memory_Pointer(result));
         return null;
      end if;

      -- Randomly increase parameters, reverting them if we exceed the cost.
      loop

         -- Line size.
         declare
            line_size : constant Positive := result.line_size;
         begin
            if Random_Boolean(RNG.Random(generator)) then
               result.line_size := line_size * 2;
               if Get_Cost(result.all) > max_cost then
                  result.line_size := line_size;
                  exit;
               end if;
            end if;
         end;

         -- Line count.
         declare
            line_count : constant Positive := result.line_count;
         begin
            if Random_Boolean(RNG.Random(generator)) then
               result.line_count := 2 * line_count;
               if Get_Cost(result.all) > max_cost then
                  result.line_count := line_count;
                  exit;
               end if;
            end if;
         end;

         -- Associativity.
         declare
            associativity : constant Positive := result.associativity;
         begin
            if Random_Boolean(RNG.Random(generator)) then
               result.associativity := result.associativity * 2;
               if result.associativity > result.line_count or else
                  Get_Cost(result.all) > max_cost then
                  result.associativity := associativity;
                  exit;
               end if;
            end if;
         end;

         -- Policy.
         declare
            policy : constant Policy_Type := result.policy;
         begin
            result.policy := Random_Policy(RNG.Random(generator));
            if Get_Cost(result.all) > max_cost then
               result.policy := policy;
               exit;
            end if;
         end;

         -- Type.
         declare
            exclusive   : constant Boolean := result.exclusive;
            write_back  : constant Boolean := result.write_back;
         begin
            result.exclusive  := Random_Boolean(RNG.Random(generator));
            result.write_back := Random_Boolean(RNG.Random(generator));
            if Get_Cost(result.all) > max_cost then
               result.exclusive := exclusive;
               result.write_back := write_back;
               exit;
            end if;
         end;

      end loop;

      -- No point in creating a worthless cache.
      Assert(Get_Cost(result.all) <= max_cost, "Invalid cache");
      if result.line_size = 1 and result.line_count = 1 then
         Destroy(Memory_Pointer(result));
         return null;
      else
         result.data.Set_Length(Count_Type(result.line_count));
         for i in 0 .. result.line_count - 1 loop
            result.data.Replace_Element(i, new Cache_Data);
         end loop;
         return Memory_Pointer(result);
      end if;

   end Random_Cache;

   function Clone(mem : Cache_Type) return Memory_Pointer is
      result : constant Cache_Pointer := new Cache_Type'(mem);
   begin
      return Memory_Pointer(result);
   end Clone;

   procedure Permute(mem         : in out Cache_Type;
                     generator   : in RNG.Generator;
                     max_cost    : in Cost_Type) is

      param_count    : constant Natural := 8;
      param          : Natural := RNG.Random(generator) mod param_count;
      line_size      : constant Positive     := mem.line_size;
      line_count     : constant Positive     := mem.line_count;
      associativity  : constant Positive     := mem.associativity;
      latency        : constant Time_Type    := mem.latency;
      policy         : constant Policy_Type  := mem.policy;
      exclusive      : constant Boolean      := mem.exclusive;
      write_back     : constant Boolean      := mem.write_back;

   begin

      -- Loop until we either change a parameter or we are unable to
      -- change any parameter.
      for i in 1 .. param_count loop
         case param is
            when 0 =>      -- Increase line size
               mem.line_size := line_size * 2;
               exit when Get_Cost(mem) <= max_cost;
               mem.line_size := line_size;
            when 1 =>      -- Decrease line size
               if line_size > 1 then
                  mem.line_size := line_size / 2;
                  exit when Get_Cost(mem) <= max_cost;
                  mem.line_size := line_size;
               end if;
            when 2 =>      -- Increase line count
               mem.line_count := line_count * 2;
               exit when Get_Cost(mem) <= max_cost;
               mem.line_count := line_count;
            when 3 =>      -- Decrease line count
               if line_count > 1 and line_count > associativity then
                  mem.line_count := line_count / 2;
                  exit when Get_Cost(mem) <= max_cost;
                  mem.line_count := line_count;
               end if;
            when 4 =>      -- Increase associativity
               if associativity < line_count then
                  mem.associativity := associativity * 2;
                  exit when Get_Cost(mem) <= max_cost;
                  mem.associativity := associativity;
               end if;
            when 5 =>      -- Decrease associativity
               if associativity > 1 and associativity > Positive(latency) then
                  mem.associativity := associativity / 2;
                  exit when Get_Cost(mem) <= max_cost;
                  mem.associativity := associativity;
               end if;
            when 6 =>      -- Change policy
               mem.policy := Random_Policy(RNG.Random(generator));
               exit when Get_Cost(mem) <= max_cost;
               mem.policy := policy;
            when others => -- Change type
               mem.exclusive  := Random_Boolean(RNG.Random(generator));
               mem.write_back := Random_Boolean(RNG.Random(generator));
               exit when Get_Cost(mem) <= max_cost;
               mem.exclusive := exclusive;
               mem.write_back := write_back;
         end case;
         param := (param + 1) mod param_count;
      end loop;

      mem.data.Set_Length(Count_Type(mem.line_count));
      for i in line_count .. mem.line_count - 1 loop
         mem.data.Replace_Element(i, new Cache_Data);
      end loop;

      Assert(Get_Cost(mem) <= max_cost, "Invalid cache permutation");

   end Permute;

   function Get_Tag(mem       : Cache_Type;
                    address   : Address_Type) return Address_Type is
      mask : constant Address_Type := not Address_Type(mem.line_size - 1);
   begin
      return address and mask;
   end Get_Tag;

   function Get_Index(mem     : Cache_Type;
                      address : Address_Type) return Natural is
      line_size   : constant Address_Type := Address_Type(mem.line_size);
      line_count  : constant Address_Type := Address_Type(mem.line_count);
      assoc       : constant Address_Type := Address_Type(mem.associativity);
      set_count   : constant Address_Type := line_count / assoc;
      base        : constant Address_Type := address / line_size;
   begin
      return Natural(base mod set_count);
   end Get_Index;

   procedure Update_Ages(mem     : in out Cache_Type;
                         first   : in Natural;
                         hit_age : in Long_Integer) is
      data : Cache_Data_Pointer;
      line : Natural;
   begin
      for i in 0 .. mem.associativity - 1 loop
         line := first + i * mem.line_count / mem.associativity;
         data := mem.data.Element(line);
         if data.age = hit_age then
            data.age := 0;
         elsif data.age < hit_age then
            data.age := data.age + 1;
         end if;
      end loop;
   end Update_Ages;

   procedure Get_Data(mem      : in out Cache_Type;
                      address  : in Address_Type;
                      size     : in Positive;
                      is_read  : in Boolean) is

      data        : Cache_Data_Pointer;
      tag         : constant Address_Type := Get_Tag(mem, address);
      first       : constant Natural := Get_Index(mem, address);
      line        : Natural;
      to_replace  : Natural := 0;
      age         : Long_Integer;

   begin

      -- Advance the time.
      Advance(mem, mem.latency);

      -- First check if this address is already in the cache.
      -- Here we also keep track of the line to be replaced.
      if mem.policy = MRU then
         age := Long_Integer'Last;
      else
         age := Long_Integer'First;
      end if;
      for i in 0 .. mem.associativity - 1 loop
         line := first + i * mem.line_count / mem.associativity;
         data := mem.data.Element(line);
         if tag = data.address then    -- Cache hit.
            if mem.policy = FIFO then
               Update_Ages(mem, first, Long_Integer'Last);
            else
               Update_Ages(mem, first, data.age);
            end if;
            if is_read or mem.write_back then
               data.dirty := data.dirty or not is_read;
            else
               Write(Container_Type(mem), tag, mem.line_size);
            end if;
            return;
         elsif mem.policy = MRU then
            if data.age < age then
               to_replace := line;
               age := data.age;
            end if;
         else
            if data.age > age then
               to_replace := line;
               age := data.age;
            end if;
         end if;
      end loop;

      -- If we got here, the item is not in the cache.
      -- If this is a read on an exclusive cache, we just forward the
      -- read the return without caching, otherwise we need to evict the
      -- oldest entry.
      if mem.exclusive and is_read then

         Read(Container_Type(mem), tag, mem.line_size);

      else

         -- Evict the oldest entry.
         -- On write-through caches, the dirty flag will never be set.
         data := mem.data.Element(to_replace);
         if data.dirty then
            Write(Container_Type(mem), data.address, mem.line_size);
            data.dirty := False;
         end if;

         -- Update the ages.
         Update_Ages(mem, first, data.age);

         -- Read the new entry.
         -- We skip this if this was a write that wrote the entire line.
         if is_read or size /= mem.line_size then
            data.address := tag;
            Read(Container_Type(mem), data.address, mem.line_size);
            data.dirty := not is_read;
         end if;

      end if;


   end Get_Data;

   procedure Reset(mem : in out Cache_Type) is
      data : Cache_Data_Pointer;
   begin
      Reset(Container_Type(mem));
      RNG.Reset(mem.generator.all);
      for i in 0 .. mem.line_count - 1 loop
         data := mem.data.Element(i);
         data.address   := Address_Type'Last;
         data.age       := 0;
         data.dirty     := False;
      end loop;
   end Reset;

   procedure Read(mem      : in out Cache_Type;
                  address  : in Address_Type;
                  size     : in Positive) is
      extra : constant Natural := size / mem.line_size;
   begin
      for i in 0 .. extra - 1 loop
         Get_Data(mem, address + Address_Type(i * mem.line_size),
                  mem.line_size, True);
      end loop;
      if size > extra * mem.line_size then
         Get_Data(mem, address + Address_Type(extra * mem.line_size),
                  size - extra * mem.line_size, True);
      end if;
   end Read;

   procedure Write(mem     : in out Cache_Type;
                   address : in Address_Type;
                   size    : in Positive) is
      extra : constant Natural := size / mem.line_size;
   begin
      for i in 0 .. extra - 1 loop
         Get_Data(mem, address + Address_Type(i * mem.line_size),
                  mem.line_size, False);
      end loop;
      if size > extra * mem.line_size then
         Get_Data(mem, address + Address_Type(extra * mem.line_size),
                  size - extra * mem.line_size, False);
      end if;
   end Write;

   function To_String(mem : Cache_Type) return Unbounded_String is
      result : Unbounded_String;
   begin
      Append(result, "(cache ");
      Append(result, "(line_size" & Positive'Image(mem.line_size) & ")");
      Append(result, "(line_count" & Positive'Image(mem.line_count) & ")");
      Append(result, "(associativity" &
             Positive'Image(mem.associativity) & ")");
      Append(result, "(latency" & Time_Type'Image(mem.latency) & ")");
      if mem.associativity > 1 then
         Append(result, "(policy ");
         case mem.policy is
            when LRU    => Append(result, "lru");
            when MRU    => Append(result, "mru");
            when FIFO   => Append(result, "fifo");
         end case;
         Append(result, ")");
      end if;
      if mem.exclusive then
         Append(result, "(exclusive true)");
      else
         Append(result,  "(exclusive false)");
      end if;
      if mem.write_back then
         Append(result, "(write_back true)");
      else
         Append(result, "(write_back false)");
      end if;
      Append(result, "(memory ");
      Append(result, To_String(Container_Type(mem)));
      Append(result, "))");
      return result;
   end To_String;

   function Get_Cost(mem : Cache_Type) return Cost_Type is

      -- Bits per line for storing data.
      lines       : constant Natural   := mem.line_count;
      lsize       : constant Natural   := mem.line_size;
      line_bits   : constant Natural   := lsize * 8;

      -- Bits to store a tag.
      addr_bits   : constant Positive  := Address_Type'Size;   -- FIXME
      wsize       : constant Positive  := Get_Word_Size(mem);
      index_bits  : constant Natural   := Log2(lines - 1);
      line_words  : constant Natural   := (lsize + wsize - 1) / wsize;
      ls_bits     : constant Natural   := Log2(line_words - 1);
      tag_bits    : constant Natural   := addr_bits - index_bits - ls_bits;

      -- Bits to store the age.
      assoc       : constant Positive  := mem.associativity;
      age_bits    : constant Natural   := Log2(assoc - 1);

      -- Bits used for storing valid and dirty.
      valid_bits  : constant Natural := 1;
      dirty_bits  : constant Natural := 1;

      -- Bits per way.  This is the width of the memory.
      width       : Natural := valid_bits + line_bits + tag_bits + age_bits;

      result : Cost_Type;

   begin

      -- If this cache is a write-back cache, we need to track a dirty
      -- bit for each cache line.
      if mem.write_back then
         width := width + dirty_bits;
      end if;

      -- The memory must be wide enough to allow access to each way.
      width := width * assoc;

      -- Given the width and depth of the cache, determine the number
      -- of BRAMs required.
      result := Cost_Type(BRAM.Get_Count(width, lines));

      -- Add the cost of the contained memory.
      result := result + Get_Cost(Container_Type(mem));

      return result;

   end Get_Cost;

   procedure Adjust(mem : in out Cache_Type) is
      ptr : Cache_Data_Pointer;
   begin
      Adjust(Container_Type(mem));
      for i in mem.data.First_Index .. mem.data.Last_Index loop
         ptr := new Cache_Data'(mem.data.Element(i).all);
         mem.data.Replace_Element(i, ptr);
      end loop;
      mem.generator := new RNG.Generator;
   end Adjust;

   procedure Free is
      new Ada.Unchecked_Deallocation(Cache_Data, Cache_Data_Pointer);

   procedure Finalize(mem : in out Cache_Type) is
   begin
      Finalize(Container_Type(mem));
      for i in mem.data.First_Index .. mem.data.Last_Index loop
         declare
            ptr : Cache_Data_Pointer := mem.data.Element(i);
         begin
            Free(ptr);
         end;
      end loop;
      Destroy(mem.generator);
   end Finalize;

   function Get_Line_Size(mem : Cache_Type) return Positive is
   begin
      return mem.line_size;
   end Get_Line_Size;

   function Get_Line_Count(mem : Cache_Type) return Positive is
   begin
      return mem.line_count;
   end Get_Line_Count;

   function Get_Associativity(mem : Cache_Type) return Positive is
   begin
      return mem.associativity;
   end Get_Associativity;

end Memory.Cache;
