
package body Memory.Prefetch is

   function Create_Prefetch(mem        : access Memory_Type'Class;
                            stride     : Address_Type := 1;
                            multiplier : Address_Type := 1)
                            return Prefetch_Pointer is
      result : constant Prefetch_Pointer := new Prefetch_Type;
   begin
      result.mem        := mem;
      result.stride     := stride;
      result.multiplier := multiplier;
      return result;
   end Create_Prefetch;

   procedure Read(mem      : in out Prefetch_Type;
                  address  : Address_Type) is
      cycles : Time_Type;
   begin

      -- Add any time left from the last prefetch.
      Advance(mem, mem.pending);

      -- Fetch the requested address.
      Start(mem.mem.all);
      Read(mem.mem.all, address);
      Commit(mem.mem.all, cycles);

      -- Prefetch the next address and save the time needed for the fetch.
      declare
         next_address : Address_Type;
      begin
         next_address := address * mem.multiplier + mem.stride;
         Start(mem.mem.all);
         Read(mem.mem.all, next_address);
         Commit(mem.mem.all, mem.pending);
      end;

      -- Add the time required to fetch the requested address.
      Advance(mem, cycles);

   end Read;

   procedure Write(mem     : in out Prefetch_Type;
                   address : Address_Type) is
      cycles : Time_Type;
   begin

      -- Add any time left from the last prefetch.
      Advance(mem, mem.pending);

      -- Write the requested address.
      Start(mem.mem.all);
      Write(mem.mem.all, address);
      Commit(mem.mem.all, cycles);

      -- Update the time.
      Advance(mem, cycles);

   end Write;

   procedure Idle(mem      : in out Prefetch_Type;
                  cycles   : in Time_Type) is
   begin
      if cycles > mem.pending then
         mem.pending := 0;
      else
         mem.pending := mem.pending - cycles;
      end if;
   end Idle;

   procedure Show_Access_Stats(mem : in Prefetch_Type) is
   begin
      Show_Access_Stats(mem.mem.all);
   end Show_Access_Stats;

   procedure Finalize(mem : in out Prefetch_Type) is
   begin
      Destroy(Memory_Pointer(mem.mem));
   end Finalize;

end Memory.Prefetch;