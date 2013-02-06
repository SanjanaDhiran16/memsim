
package body Memory.RAM is

   function Create_RAM(latency : Time_Type := 1) return RAM_Pointer is
      result : constant RAM_Pointer := new RAM_Type;
   begin
      result.latency := latency;
      return result;
   end Create_RAM;

   procedure Read(mem       : in out RAM_Type;
                  address   : in Address_Type) is
   begin
      Advance(mem, mem.latency);
   end Read;

   procedure Write(mem      : in out RAM_Type;
                   address  : in Address_Type) is
   begin
      Advance(mem, mem.latency);
   end Write;

end Memory.RAM;