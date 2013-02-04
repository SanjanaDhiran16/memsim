
package Benchmark.Heap is

   type Heap_Type is new Benchmark_Type with private;

   procedure Set_Argument(benchmark : in out Heap_Type;
                          arg       : in String);

   procedure Run(benchmark : in out Heap_Type);

private

   type Heap_Type is new Benchmark_Type with record
      size        : Positive := 1024;
      iterations  : Positive := 1000;
   end record;

end Benchmark.Heap;
