export class StringBuilder {
  private value: (string | number | boolean | null)[];

  constructor() {
    this.value = [];
  }

  append(str: string | number | boolean | null): StringBuilder {
    this.value.push(str);
    return this;
  }


  toString(): string {
    return this.value.join('');
  }
}